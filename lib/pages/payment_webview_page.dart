import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/theme/app_colors.dart';
import '../data/order_repository.dart';

/// Halaman pembayaran penyedia, dibuka **di dalam aplikasi**.
///
/// Penyedia (Sumopod) hanya mengirim `payment_link_url` dan tidak mengirim
/// muatan QRIS, jadi QR-nya ada di halaman web mereka. Menampilkannya lewat
/// webview membuat pembeli tidak terlempar ke Chrome dan tidak kehilangan
/// konteks pesanan.
///
/// Dua hal yang ditangani di sini:
/// - **Deeplink aplikasi pembayaran.** Tombol seperti "Bayar dengan GoPay"
///   memakai skema non-http (`gojek://`, `intent://`) yang tidak bisa dimuat
///   webview. Tautan seperti itu dialihkan ke aplikasi terkait; halaman web
///   tetap terbuka di belakangnya.
/// - **Kembali.** Tombol kembali menelusuri riwayat webview dulu bila ada,
///   baru menutup halaman.
class PaymentWebViewPage extends StatefulWidget {
  const PaymentWebViewPage({
    super.key,
    required this.url,
    required this.orderId,
    this.title = 'Pembayaran',
  });

  final String url;

  /// Nomor pesanan (`document_number`) yang sedang dibayar. Dipakai untuk
  /// mendeteksi pelunasan sendiri, karena penyedia tidak memberi tahu aplikasi.
  final String orderId;

  final String title;

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;

  int _progress = 0;
  String? _error;

  /// Pemantau pelunasan.
  ///
  /// Belum ada endpoint status pembayaran maupun callback dari penyedia, jadi
  /// pelunasan dikenali dari kemunculan pesanan di `GET /orders` — pesanan
  /// baru tercatat di sana setelah `pos_orders_id` terisi. Halaman pertama
  /// sudah cukup karena pesanan terbaru berada di atas.
  Timer? _poll;
  bool _checking = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _error = null);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            // Skema selain http/https = deeplink ke aplikasi pembayaran.
            if (uri != null && uri.scheme != 'http' && uri.scheme != 'https') {
              _openExternally(uri);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (e) {
            // Galat sumber daya kecil (gambar/iframe) tidak perlu menutupi
            // halaman — hanya kegagalan memuat halaman utama yang dilaporkan.
            if (e.isForMainFrame == false) return;
            if (mounted) setState(() => _error = e.description);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _startPolling() {
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _checkPaid());
  }

  /// Sekali periksa: sudahkah pesanan ini tercatat (= pembayaran masuk)?
  Future<void> _checkPaid() async {
    if (_checking || _done || widget.orderId.isEmpty) return;
    _checking = true;
    try {
      final order = await orderRepository.findByDocumentNumber(
        widget.orderId,
        maxPages: 1,
      );
      if (order != null && mounted && !_done) {
        _done = true;
        _poll?.cancel();
        // Kembalikan pesanannya supaya pemanggil bisa langsung membuka
        // halaman status tanpa memuat ulang dari awal.
        Navigator.pop(context, order);
      }
    } catch (_) {
      // Gagal memeriksa (mis. jaringan sesaat) — biarkan, percobaan
      // berikutnya menyusul 5 detik lagi.
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _openExternally(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _snack('Aplikasi pembayaran tidak ditemukan di perangkat ini.');
      }
    } catch (_) {
      if (mounted) _snack('Tidak bisa membuka aplikasi pembayaran.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Kembali: telusuri riwayat webview dulu, baru tutup halaman.
  Future<void> _back() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final loading = _progress > 0 && _progress < 100;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.textDark,
          surfaceTintColor: AppColors.white,
          centerTitle: true,
          elevation: 0,
          title: Text(
            widget.title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _back,
          ),
          actions: [
            IconButton(
              tooltip: 'Muat ulang',
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller.reload(),
            ),
            IconButton(
              tooltip: 'Selesai',
              icon: const Icon(Icons.close),
              // Periksa sekali lagi sebelum menutup — pembeli mungkin baru
              // saja membayar dan pemeriksaan berkala belum sempat jalan.
              onPressed: () async {
                await _checkPaid();
                if (!context.mounted || _done) return;
                Navigator.pop(context);
              },
            ),
          ],
          bottom: loading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: _progress / 100,
                    minHeight: 2,
                    backgroundColor: AppColors.grey100,
                    color: AppColors.maroon700,
                  ),
                )
              : null,
        ),
        body: _error != null
            ? _ErrorView(
                message: _error!,
                onRetry: () {
                  setState(() => _error = null);
                  _controller.reload();
                },
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: AppColors.grey400,
            ),
            const SizedBox(height: 12),
            const Text(
              'Halaman pembayaran gagal dimuat',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.grey600),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.maroon700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
