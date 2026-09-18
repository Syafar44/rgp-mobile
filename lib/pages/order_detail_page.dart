import 'package:flutter/material.dart';

import '../core/network/api_error.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatter.dart';
import '../data/models/order.dart';
import '../data/order_repository.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/order_card.dart';

/// Detail satu pesanan (`GET /pos/app/v1/orders/:id`).
///
/// Dibuka dari daftar pesanan maupun tepat setelah checkout. Bila [initialOrder]
/// diisi (mis. hasil checkout), isinya langsung ditampilkan sambil detail
/// terbaru diambil ulang di latar.
///
/// Mengembalikan `true` lewat `Navigator.pop` bila pesanan berubah di halaman
/// ini (dibatalkan), supaya daftar di belakangnya memuat ulang.
class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    super.key,
    required this.orderId,
    this.initialOrder,
    this.showSuccessBanner = false,
  });

  final int orderId;
  final Order? initialOrder;

  /// Tampilkan banner "pesanan berhasil dibuat" (dipakai setelah checkout).
  final bool showSuccessBanner;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Order? _order;
  bool _loading = false;
  bool _cancelling = false;
  String? _error;

  /// True bila pesanan berubah di halaman ini (dibatalkan).
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await orderRepository.detail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Bila sudah ada data dari checkout, jangan buang isinya — cukup
        // tandai bahwa penyegaran gagal.
        _error = apiErrorMessage(e, fallback: 'Gagal memuat detail pesanan.');
        _loading = false;
      });
    }
  }

  Future<void> _cancel() async {
    final order = _order;
    if (order == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: Text(
          'Pesanan ${order.documentNumber} akan dibatalkan dan tidak bisa '
          'dikembalikan. Anda perlu memesan ulang bila berubah pikiran.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Ya, batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final updated = await orderRepository.cancel(order.id);
      if (!mounted) return;
      setState(() {
        _order = updated;
        _changed = true;
        _cancelling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan dibatalkan.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppTopBar(
          title: 'Detail Pesanan',
          onBack: () => Navigator.pop(context, _changed),
        ),
        body: order == null
            ? _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.maroon700,
                      ),
                    )
                  : _ErrorView(message: _error, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.maroon700,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (widget.showSuccessBanner && order.status.isActive)
                      const _SuccessBanner(),
                    if (_error != null) _RefreshFailedNotice(message: _error!),
                    _DocumentCard(order: order),
                    const SizedBox(height: 16),
                    _InfoCard(order: order),
                    const SizedBox(height: 16),
                    _LinesCard(order: order),
                    const SizedBox(height: 16),
                    _TotalCard(order: order),
                    if (order.status.canCancel) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _cancelling ? null : _cancel,
                          icon: _cancelling
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.error,
                                  ),
                                )
                              : const Icon(Icons.close, color: AppColors.error),
                          label: const Text(
                            'Batalkan Pesanan',
                            style: TextStyle(color: AppColors.error),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// Banner setelah checkout berhasil.
class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pesanan berhasil dibuat. Tunjukkan nomor di bawah ke kasir '
              'saat mengambil.',
              style: TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshFailedNotice extends StatelessWidget {
  const _RefreshFailedNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Data mungkin belum terbaru: $message',
              style: const TextStyle(fontSize: 12, color: AppColors.grey600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nomor pesanan — ditampilkan besar karena inilah yang disebut ke kasir.
class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(order.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.creamSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Column(
        children: [
          const Text(
            'Nomor Pesanan',
            style: TextStyle(fontSize: 12, color: AppColors.grey600),
          ),
          const SizedBox(height: 6),
          SelectableText(
            order.documentNumber,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppColors.maroon700,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              order.statusLabel.isEmpty ? order.status.code : order.statusLabel,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Informasi Pengambilan',
      children: [
        _row(Icons.storefront, 'Outlet', order.outletName),
        if (order.pickupAt != null)
          _row(
            Icons.schedule,
            'Jam ambil',
            '${formatTanggal(order.pickupAt!)} WITA',
          ),
        if (order.createdAt != null)
          _row(
            Icons.receipt_long_outlined,
            'Dipesan',
            '${formatTanggal(order.createdAt!)} WITA',
          ),
        if (order.keterangan.isNotEmpty)
          _row(Icons.sticky_note_2_outlined, 'Catatan', order.keterangan),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.grey400),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.grey600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: AppColors.textDark),
          ),
        ),
      ],
    ),
  );
}

class _LinesCard extends StatelessWidget {
  const _LinesCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    if (!order.hasLines) {
      return _Card(
        title: 'Rincian Pesanan',
        children: [
          Text(
            '${order.itemCount} item',
            style: const TextStyle(fontSize: 13, color: AppColors.grey600),
          ),
        ],
      );
    }
    return _Card(
      title: 'Rincian Pesanan',
      children: [
        for (final line in order.lines) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${line.title} × ${line.quantity}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                formatRupiah(line.subtotal),
                style: const TextStyle(fontSize: 13, color: AppColors.textDark),
              ),
            ],
          ),
          // Isi paket — quantity-nya sudah dikali jumlah paket oleh server.
          for (final prop in line.props)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(
                '• ${prop.title} × ${prop.quantity}',
                style: const TextStyle(fontSize: 12, color: AppColors.grey600),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Pembayaran',
      children: [
        _row('Subtotal', formatRupiah(order.subtotalAmount)),
        if (order.discountAmount > 0)
          _row('Diskon', '- ${formatRupiah(order.discountAmount)}'),
        const Divider(height: 18),
        _row('Total', formatRupiah(order.totalAmount), bold: true),
        const SizedBox(height: 8),
        const Text(
          'Pembayaran dilakukan di kasir outlet saat pesanan diambil.',
          style: TextStyle(fontSize: 12, color: AppColors.grey600),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: bold ? 14 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? AppColors.textDark : AppColors.grey600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: bold ? AppColors.maroon700 : AppColors.textDark,
          ),
        ),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              message ?? 'Gagal memuat detail pesanan.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey600),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
