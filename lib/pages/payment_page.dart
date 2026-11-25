import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/config/app_features.dart';
import '../core/network/api_error.dart';
import '../core/utils/app_log.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatter.dart';
import '../data/auth_store.dart';
import '../data/api/payment_api.dart';
import '../data/customer_repository.dart';
import '../data/models/checkout_result.dart';
import '../data/models/order.dart';
import '../data/models/payment_charge.dart';
import '../data/notifiers.dart';
import '../data/order_repository.dart';
import '../data/order_store.dart';
import '../data/payment_repository.dart';
import 'order_status_page.dart';
import 'payment_webview_page.dart';

/// Halaman pembayaran (gateway Midtrans) — muncul tepat setelah checkout.
///
/// Tagihan dibuat di sini lalu sarana bayarnya ditampilkan **di dalam
/// aplikasi** sesuai metode: QR untuk QRIS/GoPay, nomor Virtual Account untuk
/// transfer bank, kode tagihan untuk Mandiri Bill.
///
/// Status dipantau lewat `GET /payment/api/v2/status/{order_id}` setiap 5
/// detik — server memperbaruinya dari webhook Midtrans. Tagihan berlaku 15
/// menit sejak dibuat.
/// Buka kembali halaman pembayaran untuk pesanan yang belum lunas.
///
/// Dipakai setiap kali pembeli menyentuh pesanan berstatus "Menunggu
/// pembayaran" — dari daftar Pesanan maupun dari bilah pesanan berjalan.
/// Pesanan seperti ini **belum punya id numerik**, jadi halaman status
/// pesanan memang tidak bisa memuatnya; yang masuk akal hanyalah melanjutkan
/// pembayarannya.
///
/// Mengembalikan true bila keadaan pesanan mungkin berubah, sehingga daftar
/// yang memanggilnya perlu dimuat ulang.
Future<bool> openResumePayment(BuildContext context, Order order) async {
  AppLog.info(
    'PAY',
    'lanjutkan pembayaran ${order.payableOrderId}',
    detail: 'status=${order.status.code} '
        'charge_path=${order.chargePath.isEmpty ? '(tidak dikirim server → '
              'pakai bawaan ${PaymentApi.defaultChargePath})' : order.chargePath} '
        'payment_method=${order.paymentMethod.isEmpty ? '(kosong → qris)' : order.paymentMethod}',
  );
  final changed = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => PaymentPage(checkout: order.toCheckoutResult()),
    ),
  );
  await orderStore.refresh();
  return changed ?? true;
}

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key, required this.checkout, this.simulasi = false});

  final CheckoutResult checkout;

  /// Tagihan **tiruan** — dipakai untuk bayar selisih Ganti Item selama
  /// modul itu belum punya endpoint (`ITEM_SWAP_LIVE=false`).
  ///
  /// Tampilan, dialog "Siap Melakukan Pembayaran", dan hitung mundurnya sama
  /// dengan pembayaran biasa, tetapi tidak ada satu pun permintaan ke gateway:
  /// lunas dipicu tombol "Simulasi lunas". Halaman ditutup dengan hasil
  /// `true` bila lunas, `false` bila ditinggalkan.
  final bool simulasi;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  PaymentCharge? _charge;

  /// Hitungan biaya dari server. Menentukan **nominal yang ditagih**, jadi
  /// tagihan tidak dibuat sebelum angka ini didapat.
  PaymentCalculation? _calc;

  bool _loading = true;
  String? _error;

  /// Status terkini dari server; menimpa status bawaan tagihan.
  PaymentTxStatus _status = PaymentTxStatus.pending;

  Timer? _poll;
  Timer? _tick;
  bool _checking = false;
  bool _navigated = false;

  /// Pembayaran sudah lunas tetapi pesanannya belum terbaca di `GET /orders`.
  ///
  /// Keadaan ini harus punya tampilannya sendiri: pembeli sudah membayar,
  /// jadi tidak boleh dibiarkan menatap layar pembayaran seolah belum terjadi
  /// apa-apa — tetapi juga tidak boleh diantar ke layar status yang kosong.
  bool _paidWithoutOrder = false;

  /// Sisa waktu pembayaran.
  Duration _remaining = Duration.zero;

  /// Halaman Snap sudah pernah dibuka pada layar ini.
  ///
  /// Dipakai agar pembukaan otomatis hanya terjadi sekali — setelah pembeli
  /// menutupnya sendiri, ia harus bisa tetap di layar ini (memantau status,
  /// menyalin nomor pesanan) tanpa dilempar balik ke webview.
  bool _snapOpened = false;

  /// Kelonggaran setelah `expires_at` sebelum aplikasi berhenti menunggu.
  ///
  /// Ada karena satu kelemahan Snap: bila pembeli menutup webview sebelum
  /// halamannya selesai dimuat, Midtrans tidak pernah mengirim notifikasi
  /// apa pun, sehingga `/status` bertahan di `pending` selamanya — termasuk
  /// jauh setelah tagihannya kedaluwarsa. Tanpa batas ini, layar menunggu
  /// tanpa ujung. Diberi jeda supaya pembayaran yang masuk di detik terakhir
  /// masih sempat terbaca.
  static const Duration _tenggang = Duration(minutes: 1);

  CheckoutResult get _co => widget.checkout;

  /// Tagihan selisih Ganti Item. Mati total bila modulnya dimatikan — halaman
  /// ini lalu selalu menagih lewat gateway seperti biasa.
  // TODO(ganti-item): hapus gate saat modul dirilis
  bool get _simulasi => kFiturGantiItem && widget.simulasi;

  @override
  void initState() {
    super.initState();
    // Ditunda sampai frame pertama selesai: pembuatan tagihan bisa membuka
    // dialog (menanyakan nomor HP) sebelum `await` pertama, dan `showDialog`
    // tidak boleh dipanggil selagi initState masih berjalan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _createCharge();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  // --- Tagihan ---------------------------------------------------------------

  Future<void> _createCharge() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (_simulasi) {
      await _buatTagihanTiruan();
      return;
    }

    if (!_co.canCharge) {
      setState(() {
        _loading = false;
        _error =
            'Server tidak menyebutkan cara pembayaran untuk pesanan ini. '
            'Hubungi outlet dengan menyebut nomor pesanan di bawah.';
      });
      return;
    }

    final customer = await _resolveCustomer();
    if (!mounted) return;
    if (customer == null) {
      setState(() {
        _loading = false;
        _error = 'Nomor HP diperlukan gateway pembayaran untuk membuat '
            'tagihan.';
      });
      return;
    }

    // Yang ditagih adalah total (nilai pesanan + biaya admin), sesuai yang
    // ditampilkan di checkout. Biaya admin dihitung server, bukan aplikasi.
    final PaymentCalculation calc;
    try {
      calc = await paymentRepository.calculate(
        value: _co.paymentMethod.isEmpty ? 'qris' : _co.paymentMethod,
        amount: _co.subtotalAmount,
      );
      if (!mounted) return;
      AppLog.info(
        'PAY',
        'akan ditagih ${calc.total} '
            '(nilai pesanan ${calc.amount} + biaya admin ${calc.fee})',
      );
      // Yang dikirim ke gateway adalah `total`, bukan `amount`. Kalau server
      // mengirim angka yang tidak berjumlah, catat — supaya selisih uang
      // ketahuan dari log, bukan dari keluhan pembeli.
      if (calc.total != calc.amount + calc.fee) {
        AppLog.warn(
          'PAY',
          'total dari server tidak sama dengan amount + fee',
          detail: '${calc.amount} + ${calc.fee} = ${calc.amount + calc.fee}, '
              'tetapi total=${calc.total} — yang ditagih mengikuti total',
        );
      }
      setState(() => _calc = calc);
    } catch (e) {
      if (!mounted) return;
      // Tanpa angka ini nominal tagihan tidak pasti — lebih baik berhenti
      // daripada menagih jumlah yang salah.
      setState(() {
        _loading = false;
        _error = apiErrorMessage(
          e,
          fallback: 'Gagal menghitung biaya pembayaran.',
        );
      });
      return;
    }

    final method = _resolvePaymentType(_co.paymentMethod);
    try {
      final charge = await paymentRepository.charge(
        chargePath: _co.chargePath,
        orderId: _co.orderId,
        // Yang dikirim ke gateway adalah TOTAL — nilai pesanan + biaya admin
        // (biaya sudah termasuk pajak), bukan nilai pesanan saja.
        amount: calc.total,
        paymentType: method.type,
        bank: method.bank,
        // Mandiri Bill menolak tagihan tanpa dua label ini.
        billInfo1: method.type == 'echannel' ? 'Roti Gembung Panglima' : null,
        billInfo2: method.type == 'echannel' ? _co.orderId : null,
        customerName: customer.name,
        customerEmail: customer.email,
        customerPhone: customer.phone,
      );
      if (!mounted) return;
      AppLog.info(
        'PAY',
        'tagihan dibuat ${charge.orderId}',
        detail: 'type=${charge.paymentType} gross=${charge.grossAmount} '
            'status=${charge.status.code} qr=${charge.hasQr} '
            'va=${charge.hasVa} bill=${charge.hasBill} '
            'deeplink=${charge.hasDeeplink} redirect=${charge.hasRedirect} '
            'snap=${charge.isSnap}',
      );
      setState(() {
        _charge = charge;
        _status = charge.status;
        _loading = false;
      });
      _startTimers();

      // Snap tidak mengirim sarana bayar apa pun untuk digambar di sini —
      // semuanya ada di halamannya. Tapi halaman itu tidak dibuka begitu saja:
      // pembeli diberi aba-aba lebih dulu, lengkap dengan nominal & nomor
      // pesanannya, supaya ia tahu apa yang akan terjadi dan sempat memeriksa
      // angkanya. Hanya sekali: kalau ia menutupnya, ia tetap di layar ini.
      if (charge.isSnap && !_snapOpened && mounted) {
        final lanjut = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _SiapBayarDialog(
            metode: _labelMetode(charge),
            orderId: _co.orderId,
            total: charge.grossAmount,
          ),
        );
        if (lanjut == true && mounted) await _openProviderPage();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = apiErrorMessage(e, fallback: 'Gagal membuat pembayaran.');
      });
    }
  }

  /// Tagihan tiruan untuk [PaymentPage.simulasi] — tidak ada yang dikirim ke
  /// gateway, biaya admin Rp0.
  Future<void> _buatTagihanTiruan() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final amount = _co.subtotalAmount;
    final now = DateTime.now();
    final charge = PaymentCharge(
      orderId: _co.orderId,
      transactionId: 'SIM-${now.millisecondsSinceEpoch}',
      paymentType: 'bank_transfer',
      bank: 'bni',
      vaNumber:
          '8808${(now.millisecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}',
      grossAmount: amount,
      status: PaymentTxStatus.pending,
      createdAt: now,
    );
    AppLog.warn(
      'PAY',
      'tagihan TIRUAN ${_co.orderId}',
      detail: 'selisih Ganti Item $amount · tidak ada tagihan Midtrans',
    );
    setState(() {
      _calc = PaymentCalculation(
        value: 'bni',
        amount: amount,
        fee: 0,
        total: amount,
      );
      _charge = charge;
      _status = charge.status;
      _loading = false;
    });
    _startTimers();
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SiapBayarDialog(
        metode: _labelMetode(charge),
        orderId: _co.orderId,
        total: amount,
      ),
    );
  }

  /// Tombol "Simulasi lunas" — pengganti webhook gateway.
  void _lunasTiruan() {
    _poll?.cancel();
    _tick?.cancel();
    setState(() => _status = PaymentTxStatus.settlement);
    AppLog.info('PAY', 'tagihan TIRUAN ${_co.orderId} dianggap lunas');
    _navigated = true;
    Navigator.of(context).pop(true);
  }

  /// Identitas pembeli — ketiganya wajib bagi Midtrans.
  ///
  /// Nomor HP tidak ada di `/auth` maupun `/me`; sumbernya `GET /customer/me`.
  /// Jadi bila belum tersimpan di perangkat, diambil dari server lebih dulu —
  /// bertanya ke pembeli hanya jalan terakhir.
  Future<({String name, String email, String phone})?> _resolveCustomer() async {
    final user = authStore.currentUser.value;
    var name = (user?.name ?? '').trim();
    var email = (user?.email ?? '').trim();
    var phone = (user?.phone ?? '').trim();

    if (phone.isEmpty) {
      try {
        final customer = await customerRepository.me();
        if (customer != null) {
          await authStore.applyCustomer(customer);
          phone = customer.contact.trim();
          if (name.isEmpty) name = customer.name.trim();
          if (email.isEmpty) email = customer.email.trim();
        }
      } catch (_) {
        // Gagal mengambil profil bukan penghalang — tanyakan saja.
      }
    }

    if (!mounted) return null;
    if (phone.isEmpty) {
      phone = (await _askPhone()) ?? '';
      if (phone.isEmpty) return null;
      await authStore.setPhone(phone);
    }
    return (
      name: name.isEmpty ? 'Pelanggan Panglima' : name,
      email: email,
      phone: phone,
    );
  }

  Future<String?> _askPhone() async {
    final controller = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nomor HP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gateway pembayaran memerlukan nomor HP untuk membuat tagihan.',
              style: TextStyle(fontSize: 13, color: AppColors.grey600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'cth: 081234567890',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.maroon700,
            ),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    controller.dispose();
    return phone;
  }

  /// Petakan `value` metode pembayaran ke `payment_type` Midtrans.
  ///
  /// Nama bank dikirim sebagai `value` tersendiri oleh daftar metode, jadi
  /// dipulihkan menjadi pasangan `bank_transfer` + `bank`.
  /// Nama metode pembayaran untuk ditunjukkan ke pembeli.
  String _labelMetode(PaymentCharge charge) => switch (charge.paymentType) {
    'qris' => 'QRIS',
    'gopay' => 'GoPay',
    'bank_transfer' => 'Virtual Account ${charge.bank.toUpperCase()}',
    'echannel' => 'Mandiri Bill Payment',
    'credit_card' => 'Kartu Kredit',
    _ => 'Pembayaran Online',
  };

  ({String type, String? bank}) _resolvePaymentType(String value) {
    // Bank yang diterima Midtrans untuk `bank_transfer`. BCA sengaja tidak
    // ada: belum aktif di akun production (lihat `PaymentRepository`).
    const banks = {'bni', 'bri', 'permata', 'cimb', 'bsi'};
    final v = value.trim().toLowerCase();
    if (banks.contains(v)) return (type: 'bank_transfer', bank: v);
    if (v == 'mandiri') return (type: 'echannel', bank: null);
    return (type: v.isEmpty ? 'qris' : v, bank: null);
  }

  // --- Pemantauan ------------------------------------------------------------

  void _startTimers() {
    _poll?.cancel();
    _tick?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
    _updateRemaining();
  }

  /// Batas waktu pembayaran.
  ///
  /// `expires_at` dari server didahulukan. Hitungan milik [PaymentCharge]
  /// (dibuat + 15 menit) memakai waktu tagihan dibaca aplikasi, jadi pada
  /// pembayaran yang dilanjutkan ia akan mulai dari 15 menit penuh lagi —
  /// padahal tagihannya dibuat beberapa menit sebelumnya.
  DateTime? get _expiresAt => _co.expiresAt ?? _charge?.expiresAt;

  void _updateRemaining() {
    final charge = _charge;
    final expires = _expiresAt;
    if (charge == null || expires == null || !mounted) return;
    final left = expires.difference(DateTime.now());
    setState(() => _remaining = left.isNegative ? Duration.zero : left);

    // Umumnya server yang berwenang menyatakan kedaluwarsa, dan aplikasi cukup
    // menunggu jawaban `/status`. Tapi Snap punya satu lubang: bila halaman
    // bayarnya ditutup sebelum selesai dimuat, Midtrans tidak pernah mengirim
    // notifikasi, sehingga `/status` bertahan `pending` tanpa batas. Setelah
    // [_batasMenunggu] terlampaui, layar berhenti menunggu dan mengatakannya.
    if (_status.isPending && DateTime.now().isAfter(expires.add(_tenggang))) {
      _poll?.cancel();
      _tick?.cancel();
      AppLog.warn(
        'PAY',
        'berhenti menunggu ${_co.orderId} — lewat batas '
            '${_tenggang.inMinutes} menit dari expires_at',
        detail: 'status server masih `pending`; khas Snap bila halaman '
            'bayarnya ditutup sebelum selesai dimuat.',
      );
      setState(() => _status = PaymentTxStatus.expire);
    }
  }

  Future<void> _checkStatus() async {
    if (_checking || _navigated || _charge == null || _simulasi) return;
    _checking = true;
    try {
      final status = await paymentRepository.status(_co.orderId);
      if (!mounted || status == null) return;
      if (status.status != _status) {
        AppLog.info(
          'PAY',
          'status berubah ${_status.code} → ${status.status.code}',
        );
      }
      setState(() => _status = status.status);
      if (status.status.isPaid) {
        _poll?.cancel();
        _tick?.cancel();
        await _goToPaidOrder();
      }
    } catch (_) {
      // Gagal sesaat — percobaan berikutnya menyusul 5 detik lagi.
    } finally {
      _checking = false;
    }
  }

  /// Buka halaman status pesanan setelah pembayaran lunas.
  ///
  /// Pesanan POS baru terbentuk beberapa saat setelah webhook masuk, jadi
  /// dicoba beberapa kali sebelum menyerah ke daftar pesanan.
  Future<void> _goToPaidOrder() async {
    if (_navigated) return;
    _navigated = true;

    Order? order;
    for (var i = 0; i < 3 && order == null; i++) {
      try {
        order = await orderRepository.findByDocumentNumber(
          _co.orderId,
          maxPages: 1,
        );
      } catch (_) {
        // abaikan, coba lagi
      }
      if (order == null) await Future<void>.delayed(const Duration(seconds: 2));
    }
    await orderStore.refresh();
    if (!mounted) return;

    if (order == null) {
      AppLog.warn(
        'PAY',
        'LUNAS tetapi pesanan belum terbaca — tetap di halaman pembayaran',
        detail: 'order_id=${_co.orderId} · tidak berpindah ke halaman status '
            'karena id pesanan tidak tersedia',
      );
      // Pembayaran masuk, tetapi pesanannya belum terbaca sistem.
      //
      // JANGAN pindah ke halaman status: halaman itu akan tampil kosong dan
      // pembeli tidak punya cara tahu apakah pesanannya jadi. Tetap di sini
      // dengan pernyataan yang jujur — uang sudah diterima, nomor pesanannya
      // ini, dan sediakan tombol periksa ulang.
      _navigated = false;
      setState(() => _paidWithoutOrder = true);
      return;
    }
    AppLog.info('PAY', 'lunas → buka status pesanan id=${order.id}');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderStatusPage(
          orderId: order!.id,
          initialOrder: order,
          justPaid: true,
        ),
      ),
    );
  }

  /// Periksa ulang apakah pesanan sudah tercatat, setelah pembayaran lunas.
  Future<void> _recheckOrder() async {
    if (_checking) return;
    setState(() => _checking = true);
    await _goToPaidOrder();
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _refresh() async {
    if (_charge == null && !_loading) {
      await _createCharge();
      return;
    }
    await _checkStatus();
    if (mounted && _status.isPending) {
      _snack('Pembayaran belum masuk. Coba lagi beberapa saat lagi.');
    }
  }

  // --- Aksi ------------------------------------------------------------------

  Future<void> _copy(String text, String message) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    _snack(message);
  }

  Future<void> _openDeeplink() async {
    final url = _charge?.deeplinkUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _snack('Aplikasi pembayaran tidak ditemukan.');
    } catch (_) {
      if (mounted) _snack('Tidak bisa membuka aplikasi pembayaran.');
    }
  }

  /// Buka halaman bayar penyedia di dalam aplikasi.
  ///
  /// Dua kasus memakainya: halaman **Snap** (nomor VA / QR-nya ditampilkan di
  /// sana, bukan di sini) dan verifikasi 3DS kartu kredit.
  ///
  /// Halaman Snap tidak pernah menutup dirinya sendiri dan tidak melakukan
  /// redirect yang bisa dikenali, jadi aplikasi sengaja **tidak membaca URL
  /// apa pun** dari webview. Acuannya tetap `GET /status/{order_id}`, yang
  /// terus berjalan walau webview sudah ditutup — pembayaran VA biasanya
  /// diselesaikan di m-banking, di luar aplikasi.
  Future<void> _openProviderPage() async {
    final url = _charge?.redirectUrl;
    if (url == null || url.isEmpty) return;
    _snapOpened = true;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentWebViewPage(
          url: url,
          orderId: _co.orderId,
          title: _charge?.isSnap == true ? 'Pembayaran' : 'Verifikasi Kartu',
        ),
      ),
    );
    if (mounted) await _checkStatus();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToOrders() {
    // Tagihan selisih dibuka dari halaman Pilih Pengganti — kembali ke sana.
    if (_simulasi) {
      Navigator.of(context).pop(false);
      return;
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
    selectedPageNotifier.value = 3; // tab Pesanan
  }

  Future<bool> _confirmLeave() async {
    if (_status.isPaid || _status.isDead) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tinggalkan pembayaran?'),
        content: Text(
          _simulasi
              ? 'Selisih ${_co.orderId} belum dibayar. Pengganti belum '
                    'tersimpan sampai selisihnya lunas.'
              : 'Pesanan ${_co.orderId} belum dibayar. Tagihan ini berlaku 15 '
                    'menit dan belum tercatat di daftar pesanan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tetap di sini'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  // --- Tampilan --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final charge = _charge;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted) _goToOrders();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.textDark,
          surfaceTintColor: AppColors.white,
          centerTitle: true,
          elevation: 0,
          title: const Text(
            'Pembayaran',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _confirmLeave() && mounted) _goToOrders();
            },
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.maroon700,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _HeaderCard(
                orderId: _co.orderId,
                status: _status,
                remaining: _charge == null ? null : _remaining,
                onCopy: () => _copy(_co.orderId, 'Nomor pesanan disalin.'),
              ),
              const SizedBox(height: 16),
              if (_paidWithoutOrder)
                _PaidPendingRecordBox(
                  orderId: _co.orderId,
                  amount: charge?.grossAmount ?? _calc?.total ?? 0,
                  checking: _checking,
                  onRecheck: _recheckOrder,
                  onSeeOrders: _goToOrders,
                )
              else if (_loading)
                const _LoadingBox()
              else if (_error != null)
                _ErrorBox(message: _error!, onRetry: _createCharge)
              else if (charge != null && _status.isDead)
                _DeadBox(status: _status, onBackToOrders: _goToOrders)
              else if (charge != null) ...[
                _InstrumentCard(
                  charge: charge,
                  onCopyVa: () =>
                      _copy(charge.vaNumber, 'Nomor Virtual Account disalin.'),
                  onCopyBillKey: () =>
                      _copy(charge.billKey, 'Kode pembayaran disalin.'),
                  onCopyBillerCode: () =>
                      _copy(charge.billerCode, 'Kode perusahaan disalin.'),
                  onDeeplink: _openDeeplink,
                  on3ds: _openProviderPage,
                ),
                const SizedBox(height: 16),
                _AmountCard(charge: charge, calc: _calc),
                if (charge.hasInstruction) ...[
                  const SizedBox(height: 16),
                  _InstructionCard(html: charge.instructionHtml),
                ],
                const SizedBox(height: 16),
                if (_simulasi)
                  _SimulasiLunasBox(onLunas: _lunasTiruan)
                else
                  const _PollingHint(),
              ],
              const SizedBox(height: 12),
              if (!_simulasi)
                Center(
                  child: TextButton(
                    onPressed: _goToOrders,
                    child: const Text(
                      'Lihat daftar pesanan',
                      style: TextStyle(
                        color: AppColors.maroon700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// HEADER
// =============================================================================

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.orderId,
    required this.status,
    required this.remaining,
    required this.onCopy,
  });

  final String orderId;
  final PaymentTxStatus status;
  final Duration? remaining;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final color = status.isPaid
        ? AppColors.success
        : status.isDead
        ? AppColors.error
        : AppColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onCopy,
            child: Text(
              orderId,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: AppColors.maroon700,
              ),
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
              status.label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (remaining != null && status.isPending) ...[
            const SizedBox(height: 10),
            Text(
              remaining! == Duration.zero
                  ? 'Waktu pembayaran habis — menunggu konfirmasi server'
                  : 'Bayar dalam ${_mmss(remaining!)}',
              style: const TextStyle(fontSize: 12, color: AppColors.grey600),
            ),
          ],
        ],
      ),
    );
  }

  static String _mmss(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// =============================================================================
// SARANA BAYAR
// =============================================================================

/// Menampilkan sarana bayar sesuai `payment_type` dari server.
class _InstrumentCard extends StatelessWidget {
  const _InstrumentCard({
    required this.charge,
    required this.onCopyVa,
    required this.onCopyBillKey,
    required this.onCopyBillerCode,
    required this.onDeeplink,
    required this.on3ds,
  });

  final PaymentCharge charge;
  final VoidCallback onCopyVa;
  final VoidCallback onCopyBillKey;
  final VoidCallback onCopyBillerCode;
  final VoidCallback onDeeplink;
  final VoidCallback on3ds;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Column(
        children: [
          Text(
            _title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.grey600),
          ),
          const SizedBox(height: 16),
          if (charge.hasQr) _qr(),
          if (charge.hasVa) _va(),
          if (charge.hasBill) _bill(),
          if (charge.hasDeeplink) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: onDeeplink,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Buka aplikasi pembayaran'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          if (charge.hasRedirect) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: on3ds,
                icon: Icon(
                  charge.isSnap
                      ? Icons.open_in_new
                      : Icons.verified_user_outlined,
                  size: 18,
                ),
                label: Text(
                  charge.isSnap
                      ? 'Buka Halaman Pembayaran'
                      : 'Lanjutkan Verifikasi Kartu',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (charge.isSnap) ...[
              const SizedBox(height: 10),
              Text(
                'Nomor Virtual Account / kode QR ditampilkan di halaman itu. '
                'Setelah membayar, halaman boleh ditutup — status pesanan '
                'tetap dipantau dari layar ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: AppColors.grey600,
                ),
              ),
            ],
          ],
          if (!charge.hasQr &&
              !charge.hasVa &&
              !charge.hasBill &&
              !charge.hasDeeplink &&
              !charge.hasRedirect)
            const Text(
              'Ikuti petunjuk pembayaran di bawah.',
              style: TextStyle(fontSize: 12, color: AppColors.grey600),
            ),
        ],
      ),
    );
  }

  String get _title => switch (charge.paymentType) {
    'qris' => 'Pindai QRIS',
    'gopay' => 'Pindai dengan GoPay',
    'bank_transfer' => 'Transfer Bank ${charge.bank.toUpperCase()}',
    'echannel' => 'Mandiri Bill Payment',
    'credit_card' => 'Kartu Kredit',
    _ => 'Selesaikan Pembayaran',
  };

  String get _subtitle => switch (charge.paymentType) {
    'qris' => 'Buka aplikasi bank atau e-wallet, lalu pindai kode ini.',
    'gopay' => 'Pindai dengan aplikasi Gojek, atau ketuk tombol di bawah.',
    'bank_transfer' =>
      'Transfer tepat sesuai nominal ke nomor Virtual Account berikut.',
    'echannel' =>
      'Masukkan kode perusahaan & kode pembayaran di ATM/aplikasi Mandiri.',
    'credit_card' => 'Verifikasi kartu Anda untuk menyelesaikan pembayaran.',
    _ => '',
  };

  /// QR datang sebagai **URL gambar** dari Midtrans, jadi ditampilkan apa
  /// adanya — tidak digambar ulang dari muatan QRIS.
  Widget _qr() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.grey300),
    ),
    child: Image.network(
      charge.qrCode,
      width: 220,
      height: 220,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const SizedBox(
              width: 220,
              height: 220,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.maroon700),
              ),
            ),
      errorBuilder: (_, __, ___) => const SizedBox(
        width: 220,
        height: 220,
        child: Center(
          child: Text(
            'Gagal memuat QR.\nTarik layar untuk mencoba lagi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.grey600),
          ),
        ),
      ),
    ),
  );

  Widget _va() => _CodeBox(
    label: 'Nomor Virtual Account',
    value: charge.vaNumber,
    onCopy: onCopyVa,
  );

  Widget _bill() => Column(
    children: [
      _CodeBox(
        label: 'Kode Perusahaan',
        value: charge.billerCode,
        onCopy: onCopyBillerCode,
      ),
      const SizedBox(height: 10),
      _CodeBox(
        label: 'Kode Pembayaran',
        value: charge.billKey,
        onCopy: onCopyBillKey,
      ),
    ],
  );
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.creamSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.grey600,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 18),
            color: AppColors.maroon700,
            tooltip: 'Salin',
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// NOMINAL, INSTRUKSI, KEADAAN
// =============================================================================

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.charge, required this.calc});

  final PaymentCharge charge;
  final PaymentCalculation? calc;

  @override
  Widget build(BuildContext context) {
    // `gross_amount` dari gateway adalah nominal yang benar-benar ditagih.
    final total = charge.grossAmount;
    final fee = calc?.fee;
    final amount = calc?.amount ?? (fee == null ? total : total - fee);

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
          const Text(
            'Rincian Pembayaran',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _row('Subtotal', formatRupiah(amount)),
          const Divider(height: 18),
          _row('Biaya Admin', fee == null ? '—' : formatRupiah(fee)),
          const Divider(height: 18),
          _row('Total Pembayaran', formatRupiah(total), bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Row(
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
          fontSize: bold ? 16 : 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          color: bold ? AppColors.maroon700 : AppColors.textDark,
        ),
      ),
    ],
  );
}

/// Instruksi pembayaran dari server, berupa HTML siap tampil.
///
/// Dirender memakai webview yang sudah menjadi dependensi aplikasi, jadi tidak
/// perlu paket perender HTML tambahan.
class _InstructionCard extends StatefulWidget {
  const _InstructionCard({required this.html});

  final String html;

  @override
  State<_InstructionCard> createState() => _InstructionCardState();
}

class _InstructionCardState extends State<_InstructionCard> {
  WebViewController? _controller;
  bool _open = false;

  void _ensureController() {
    if (_controller != null) return;
    _controller = WebViewController()
      ..setBackgroundColor(AppColors.white)
      ..loadHtmlString('''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
 body { font-family: -apple-system, system-ui, sans-serif; font-size: 14px;
        color: #2b2b2b; margin: 0; padding: 4px 2px; line-height: 1.5; }
 ol, ul { padding-left: 18px; }
</style>
</head><body>${widget.html}</body></html>''');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey100),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: const Text(
          'Cara Pembayaran',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        shape: const Border(),
        onExpansionChanged: (open) {
          if (open) _ensureController();
          setState(() => _open = open);
        },
        children: [
          SizedBox(
            height: 280,
            child: _open && _controller != null
                ? WebViewWidget(controller: _controller!)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Pengganti webhook pada tagihan tiruan. Hanya muncul di [PaymentPage.simulasi].
class _SimulasiLunasBox extends StatelessWidget {
  const _SimulasiLunasBox({required this.onLunas});

  final VoidCallback onLunas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Text(
            'SIMULASI — tidak ada tagihan sungguhan. Nomor di atas tidak bisa '
            'dibayar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.warning),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onLunas,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Simulasi lunas'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warning,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PollingHint extends StatelessWidget {
  const _PollingHint();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.autorenew, size: 16, color: AppColors.grey400),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            'Halaman ini memeriksa pembayaran secara otomatis.',
            style: TextStyle(fontSize: 12, color: AppColors.grey600),
          ),
        ),
      ],
    );
  }
}

/// Pembayaran lunas, tetapi pesanannya belum terbaca sistem.
///
/// Keadaan paling sensitif di seluruh aplikasi: uang pembeli sudah keluar.
/// Karena itu yang ditampilkan hanya yang pasti benar — pembayaran diterima
/// dan nomor pesanannya ini — bukan status pengambilan yang belum diketahui.
class _PaidPendingRecordBox extends StatelessWidget {
  const _PaidPendingRecordBox({
    required this.orderId,
    required this.amount,
    required this.checking,
    required this.onRecheck,
    required this.onSeeOrders,
  });

  final String orderId;
  final int amount;
  final bool checking;
  final VoidCallback onRecheck;
  final VoidCallback onSeeOrders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  amount > 0
                      ? 'Pembayaran ${formatRupiah(amount)} diterima'
                      : 'Pembayaran diterima',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Pesanan Anda sedang dicatat sistem outlet dan belum muncul di '
            'daftar pesanan. Uang Anda sudah masuk — simpan nomor pesanan di '
            'atas dan tunjukkan ke kasir bila diperlukan.',
            style: TextStyle(fontSize: 13, color: AppColors.textDark),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: checking ? null : onRecheck,
              icon: checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(
                checking ? 'Memeriksa…' : 'Periksa lagi',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.maroon700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: onSeeOrders,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.maroon700,
                side: const BorderSide(color: AppColors.maroon700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Lihat daftar pesanan'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Bila setelah beberapa menit pesanan tetap tidak muncul, hubungi '
            'outlet dengan menyebut nomor pesanan ini.',
            style: TextStyle(fontSize: 12, color: AppColors.grey600),
          ),
        ],
      ),
    );
  }
}

/// Tagihan sudah tidak bisa dibayar (kedaluwarsa, dibatalkan, ditolak).
class _DeadBox extends StatelessWidget {
  const _DeadBox({required this.status, required this.onBackToOrders});

  final PaymentTxStatus status;
  final VoidCallback onBackToOrders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.timer_off_outlined, color: AppColors.error, size: 32),
          const SizedBox(height: 10),
          Text(
            status.label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tagihan ini sudah tidak berlaku. Silakan buat pesanan baru.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.grey600),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onBackToOrders,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.maroon700,
              ),
              child: const Text('Kembali'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.maroon700),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba lagi'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aba-aba sebelum halaman bayar penyedia dibuka.
///
/// Halaman Snap dibuka otomatis karena memang tidak ada apa pun yang bisa
/// digambar aplikasi. Tanpa jeda ini, layar berpindah sendiri ke tampilan
/// Midtrans beberapa saat setelah pembeli menekan "Pesan" — mengejutkan, dan
/// ia kehilangan kesempatan memeriksa nominalnya lebih dulu.
class _SiapBayarDialog extends StatelessWidget {
  const _SiapBayarDialog({
    required this.metode,
    required this.orderId,
    required this.total,
  });

  final String metode;
  final String orderId;
  final int total;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // `Center` wajib: slot ikon `AlertDialog` berada di kolom yang meregang
      // selebar dialog, jadi tanpa ini lingkarannya tergambar lonjong.
      icon: Center(
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.maroon50,
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: AppColors.maroon700,
            size: 28,
          ),
        ),
      ),
      title: const Text(
        'Siap Melakukan Pembayaran',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Anda akan diarahkan ke halaman pembayaran. Nomor Virtual Account '
            'atau kode QR ditampilkan di sana.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.grey600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.creamSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _baris('Metode', metode),
                const SizedBox(height: 6),
                _baris('Nomor pesanan', orderId),
                const Divider(height: 18),
                _baris('Total', formatRupiah(total), tebal: true),
              ],
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Lanjutkan Bayar'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.maroon700,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            // Tagihannya tetap hidup — pembeli kembali ke layar pembayaran
            // dan bisa membukanya lagi selama belum kedaluwarsa.
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Nanti Saja',
              style: TextStyle(color: AppColors.grey600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _baris(String label, String nilai, {bool tebal = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: tebal ? 13 : 12,
          color: AppColors.grey600,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          nilai,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: tebal ? 15 : 12.5,
            fontWeight: tebal ? FontWeight.bold : FontWeight.w600,
            color: tebal ? AppColors.maroon700 : AppColors.textDark,
          ),
        ),
      ),
    ],
  );
}
