import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config/app_features.dart';
import '../core/config/fees.dart';
import '../core/network/api_error.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatter.dart';
import '../core/utils/wita.dart';
import '../data/address_store.dart';
import '../data/cart_store.dart';
import '../data/dummy/dummy_data.dart';
import '../data/models/cart.dart';
import '../data/models/payment_charge.dart';
import '../data/models/payment_method.dart';
import '../data/models/saved_address.dart';
import '../data/order_repository.dart';
import '../data/payment_repository.dart';
import '../widgets/network_guard.dart';
import '../widgets/verified_email_guard.dart';
import '../widgets/ongoing_order_guard.dart';
import 'outlet_page.dart';
import 'payment_page.dart';

/// Ikon untuk sebuah metode pembayaran. Server mengirim `file` (logo) yang
/// bisa kosong, jadi ikon Material dipakai sebagai cadangan berdasarkan `type`.
IconData _payIcon(PaymentMethod m) {
  switch (m.type.toLowerCase()) {
    case 'qris':
      return Icons.qr_code_2;
    case 'va':
    case 'bank':
    case 'bank_transfer':
      return Icons.account_balance;
    case 'ewallet':
    case 'e-wallet':
      return Icons.account_balance_wallet;
    case 'cash':
    case 'tunai':
      return Icons.payments_outlined;
    default:
      return Icons.payment;
  }
}

/// Halaman Checkout — memilih pembayaran & menyelesaikan pesanan.
///
/// Dibuka dari halaman Konfirmasi Pesanan setelah metode (Pickup/Delivery)
/// dikonfirmasi.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.isDelivery,
    required this.outlet,
  });

  final bool isDelivery;
  final Outlet outlet;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _redeemPoints = false;
  int _payMethod = 0;

  /// Jam ambil pilihan pembeli (jam dinding WITA). Null = "Pickup Sekarang";
  /// server memakai bawaannya, yaitu 1 jam dari sekarang.
  DateTime? _pickupAt;

  /// Catatan untuk outlet (`keterangan`, maks 255 karakter).
  final TextEditingController _note = TextEditingController();

  /// True selama `POST .../checkout` berjalan.
  bool _placing = false;

  /// Metode pembayaran dari `GET /payment/api/v2/payment-methods`.
  List<PaymentMethod> _methods = const [];
  bool _loadingMethods = true;
  String? _methodsError;

  /// Biaya admin versi server untuk metode terpilih (`.../calculate`).
  /// Null bila belum/ gagal dihitung — UI jatuh ke pratinjau lokal.
  PaymentCalculation? _calc;

  bool get _isDelivery => widget.isDelivery;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() {
      _loadingMethods = true;
      _methodsError = null;
    });
    try {
      // Urutan dibalik dari yang dikirim server (permintaan tampilan).
      final ordered = (await paymentRepository.methods()).reversed.toList(
        growable: false,
      );
      if (!mounted) return;
      setState(() {
        _methods = ordered;
        // QRIS tetap terpilih lebih dulu. Dicari berdasarkan tipenya, bukan
        // index 0 — setelah urutannya dibalik, posisi pertama belum tentu QRIS.
        _payMethod = _defaultMethodIndex(ordered);
        _loadingMethods = false;
      });
      await _recalculate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _methodsError = apiErrorMessage(
          e,
          fallback: 'Gagal memuat metode pembayaran.',
        );
        _loadingMethods = false;
      });
    }
  }

  /// Metode yang terpilih saat halaman dibuka: QRIS bila ada, selain itu
  /// yang pertama. Tidak boleh mengandalkan index 0 karena urutan daftarnya
  /// dibalik dari yang dikirim server.
  int _defaultMethodIndex(List<PaymentMethod> methods) {
    final i = methods.indexWhere((m) => m.type.toLowerCase() == 'qris');
    return i >= 0 ? i : 0;
  }

  String? get _scheduleLabel =>
      _pickupAt == null ? null : formatJamWita(_pickupAt!);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  // --- Rincian harga --------------------------------------------------------

  // Angka mengikuti server: `amount`/`fee`/`total` dari
  // `POST /payment/api/v2/payment-methods/calculate`. Selama hasilnya belum
  // ada, tampilkan total keranjang apa adanya tanpa biaya admin.

  int get _amount => _calc?.amount ?? cartStore.total;
  int get _fee => _calc?.fee ?? 0;
  int get _payTotal => _calc?.total ?? cartStore.total;

  // --- Aksi -----------------------------------------------------------------

  /// Konfirmasi keluar dari halaman. Mengembalikan true bila boleh keluar.
  Future<bool> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ExitDialog(),
    );
    return leave ?? false;
  }

  /// Minta server menghitung biaya admin untuk metode & nominal saat ini.
  ///
  /// Nominalnya memakai total keranjang dari server — itu yang nanti jadi
  /// `total_amount` pesanan, bukan total lokal yang masih memuat poin/ongkir
  /// bikinan aplikasi.
  Future<void> _recalculate() async {
    final method = (_payMethod >= 0 && _payMethod < _methods.length)
        ? _methods[_payMethod]
        : null;
    final amount = cartStore.total;
    if (method == null || amount < 1) {
      if (mounted) setState(() => _calc = null);
      return;
    }
    try {
      final calc = await paymentRepository.calculate(
        value: method.value,
        amount: amount,
      );
      if (!mounted) return;
      setState(() => _calc = calc);
    } catch (_) {
      // Gagal menghitung bukan penghalang: pesanan belum dibayar di sini, dan
      // kartu metode masih menampilkan pratinjau hitungan lokal.
      if (mounted) setState(() => _calc = null);
    }
  }

  Future<void> _showAllPayments() async {
    if (_methods.isEmpty) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) =>
          _AllPaymentsSheet(methods: _methods, selected: _payMethod),
    );
    if (picked == null) return;
    setState(() => _payMethod = picked);
    await _recalculate();
  }

  Future<void> _schedulePickup() async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _SchedulePickupSheet(),
    );
    if (result == null) return;
    // Sentinel 'now' berarti "Pickup Sekarang" (pickup_at tidak dikirim).
    setState(() => _pickupAt = result is DateTime ? result : null);
  }

  /// Ubah keranjang menjadi pesanan (`POST .../checkout`).
  ///
  /// Server yang menghitung ulang harga & memotong keranjang; aplikasi hanya
  /// mengirim jam ambil dan catatan.
  Future<void> _placeOrder() async {
    // Server mewajibkan `payment_method`, jadi pesanan tidak bisa dibuat
    // sebelum daftar metode termuat.
    final method = (_payMethod >= 0 && _payMethod < _methods.length)
        ? _methods[_payMethod]
        : null;
    if (method == null) {
      _showOrderError(
        'Metode pembayaran belum tersedia. Muat ulang metode pembayaran '
        'lalu coba lagi.',
      );
      return;
    }

    // Email belum terverifikasi → tidak boleh membuat pesanan.
    // Menjelajah menu & mengisi keranjang tetap bebas.
    if (!await ensureEmailVerified(context) || !mounted) return;

    // Inilah detik pesanan benar-benar dikirim. Jaringan yang putus di sini
    // bisa menghasilkan pesanan yang terbentuk di server tapi dianggap gagal
    // oleh aplikasi — lalu ditekan ulang, dan jadilah dua tagihan.
    if (!await ensureNetworkReady(context) || !mounted) return;

    // Penjaga kedua "satu pesanan pada satu waktu". Halaman ini bisa sudah
    // terbuka sejak sebelum pesanan lain dibuat (mis. lewat notifikasi atau
    // layar lain), jadi keadaannya diperiksa lagi di detik terakhir.
    if (!await ensureNoOngoingOrder(context) || !mounted) return;

    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() => _placing = true);
    try {
      final order = await orderRepository.checkout(
        widget.outlet.id,
        paymentMethod: method.value,
        pickupAt: _pickupAt,
        keterangan: _note.text,
      );
      // Server sudah mengosongkan keranjang; samakan keadaan lokal.
      await cartStore.loadFor(widget.outlet.id);
      if (!mounted) return;

      // Alur server adalah bayar-dulu. Tagihan dibuat di halaman pembayaran
      // (bukan di sini) karena gateway butuh identitas pembeli dan sarana
      // bayarnya berbeda-beda per metode.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PaymentPage(checkout: order)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      _showOrderError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      _showOrderError(apiErrorMessage(e));
    }
  }

  void _showOrderError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmExit();
        if (!context.mounted) return;
        if (leave) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.textDark,
          surfaceTintColor: AppColors.white,
          // AppBar putih → ikon status bar hitam.
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          centerTitle: true,
          elevation: 0,
          title: const Text(
            'Checkout',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final leave = await _confirmExit();
              if (!context.mounted) return;
              if (leave) Navigator.pop(context);
            },
          ),
        ),
        body: ValueListenableBuilder<ServerCart>(
          valueListenable: cartStore.cart,
          builder: (context, cart, _) {
            final items = cart.items;
            if (items.isEmpty) {
              return const Center(child: Text('Keranjang kosong'));
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _isDelivery
                    ? _RouteCard(outlet: widget.outlet)
                    : _PickupInfoCard(
                        outlet: widget.outlet,
                        pickupAt: _pickupAt,
                      ),
                if (AppFeatures.loyalty) ...[
                  const SizedBox(height: 20),
                  _PointsRedeem(
                    redeem: _redeemPoints,
                    onChanged: (v) => setState(() => _redeemPoints = v),
                  ),
                ],
                const SizedBox(height: 20),
                _PaymentSection(
                  methods: _methods,
                  selected: _payMethod,
                  loading: _loadingMethods,
                  error: _methodsError,
                  // Biaya layanan dihitung dari nilai yang benar-benar
                  // ditagih server (isi keranjang), bukan total lokal.
                  amount: cart.total,
                  calculation: _calc,
                  onSelect: (i) {
                    setState(() => _payMethod = i);
                    _recalculate();
                  },
                  onSeeAll: _showAllPayments,
                  onRetry: _loadPaymentMethods,
                ),
                const SizedBox(height: 20),
                _OrderSummary(items: items),
                if (_isDelivery) ...[
                  const SizedBox(height: 12),
                  const _WarningBanner(),
                  const SizedBox(height: 12),
                  const _InstantDeliveryInfo(),
                ],
                const SizedBox(height: 16),
                _NoteField(controller: _note),
                const SizedBox(height: 16),
                _Breakdown(amount: _amount, fee: _fee, total: _payTotal),
                const SizedBox(height: 10),
                // _TotalNote(orderTotal: cart.total),
                if (_isDelivery) ...[
                  const SizedBox(height: 12),
                  const _DeliveryUnavailableNotice(),
                ],
              ],
            );
          },
        ),
        bottomNavigationBar: _CheckoutBottomBar(
          total: _payTotal,
          // Penjadwalan jam ambil belum ada fiturnya — server mengisi
          // `pickup_at` sendiri (1 jam dari pesan). Tombolnya dimatikan
          // ketimbang menawarkan pilihan yang tidak berpengaruh.
          showSchedule: false,
          scheduleLabel: _scheduleLabel,
          onSchedule: _schedulePickup,
          // Endpoint checkout hanya membuat pesanan pickup; pengantaran belum
          // ada di API, jadi jangan biarkan pesanan delivery terkirim.
          // Metode pembayaran juga wajib, jadi tunggu daftarnya termuat.
          onPay: (_placing || _isDelivery || _methods.isEmpty)
              ? null
              : _placeOrder,
          loading: _placing,
        ),
      ),
    );
  }
}

// =============================================================================
// KARTU RUTE (delivery) & INFO PICKUP
// =============================================================================

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.outlet});

  final Outlet outlet;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SavedAddress>>(
      valueListenable: addressStore.notifier,
      builder: (context, addresses, _) {
        final addr = addresses.isEmpty
            ? null
            : addresses.firstWhere(
                (a) => a.isPrimary,
                orElse: () => addresses.first,
              );
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indikator rute (titik atas → garis → titik bawah).
                Column(
                  children: [
                    const _RouteDot(filled: false),
                    Expanded(
                      child: Container(width: 2, color: AppColors.grey300),
                    ),
                    const _RouteDot(filled: true),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _routeLine('Outlet', outlet.name),
                      const SizedBox(height: 16),
                      _routeLine(
                        'Dikirim ke',
                        addr?.label ?? 'Pilih alamat',
                        subtitle: addr?.fullAddress,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _routeLine(String label, String value, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.grey600)),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: AppColors.grey600),
          ),
        ],
      ],
    );
  }
}

class _RouteDot extends StatelessWidget {
  const _RouteDot({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.success : AppColors.white,
        border: Border.all(color: AppColors.success, width: 2),
      ),
    );
  }
}

class _PickupInfoCard extends StatelessWidget {
  const _PickupInfoCard({required this.outlet, this.pickupAt});

  final Outlet outlet;

  /// Jam ambil pilihan pembeli. Null = belum dijadwalkan, sehingga server
  /// mengisinya sendiri dengan 1 jam dari waktu pesan.
  final DateTime? pickupAt;

  @override
  Widget build(BuildContext context) {
    final terjadwal = pickupAt != null;
    // Samakan dengan bawaan server supaya pembeli tidak kaget melihat jam
    // yang tidak pernah ia pilih pada detail pesanan.
    final jam = terjadwal ? pickupAt! : nowWita().add(const Duration(hours: 1));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _row(
            icon: Icons.storefront,
            iconColor: AppColors.gold500,
            label: 'Outlet',
            value: outlet.name,
          ),
          const Divider(height: 20),
          _row(
            icon: Icons.point_of_sale,
            iconColor: AppColors.info,
            label: 'Opsi Pickup',
            value: 'Pickup di Counter',
          ),
          const Divider(height: 20),
          _row(
            icon: Icons.schedule,
            iconColor: AppColors.info,
            label: terjadwal ? 'Jam Ambil' : 'Jam Ambil (otomatis)',
            value: '${formatJamWita(jam)} WITA',
            // Tidak lagi menyebut tombol "Jadwalkan": tombolnya dimatikan
            // sampai fiturnya ada, dan menunjuk tombol yang tidak kelihatan
            // lebih membingungkan daripada tidak menjelaskan apa-apa.
            hint: terjadwal
                ? null
                : 'Dihitung otomatis 1 jam dari waktu pesan.',
          ),
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? hint,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: AppColors.grey600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 4),
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: AppColors.grey600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// PANGLIMA POINTS (redeem)
// =============================================================================

class _PointsRedeem extends StatelessWidget {
  const _PointsRedeem({required this.redeem, required this.onChanged});

  final bool redeem;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Panglima Points',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => onChanged(!redeem),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.yellow50,
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    color: AppColors.gold500,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Redeem ${DummyData.poin} pts',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.maroon700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '1 Panglima Point = 1 Rupiah',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: redeem,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: AppColors.maroon700,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// PEMBAYARAN LANGSUNG (metode)
// =============================================================================

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
    required this.methods,
    required this.selected,
    required this.loading,
    required this.error,
    required this.amount,
    required this.calculation,
    required this.onSelect,
    required this.onSeeAll,
    required this.onRetry,
  });

  final List<PaymentMethod> methods;
  final int selected;
  final bool loading;
  final String? error;

  /// Nominal untuk menghitung biaya layanan (total keranjang dari server).
  final int amount;

  /// Hitungan biaya dari server (`.../calculate`). Null bila belum tersedia —
  /// tampilan jatuh ke pratinjau lokal.
  final PaymentCalculation? calculation;

  final ValueChanged<int> onSelect;
  final VoidCallback onSeeAll;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final current = (selected >= 0 && selected < methods.length)
        ? methods[selected]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Pembayaran Langsung',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (methods.length > 1)
              GestureDetector(
                onTap: onSeeAll,
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(
                    color: AppColors.info,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.maroon700,
                ),
              ),
            ),
          )
        else if (error != null)
          _PaymentNotice(
            icon: Icons.cloud_off_outlined,
            color: AppColors.error,
            message: error!,
            actionLabel: 'Coba lagi',
            onAction: onRetry,
          )
        else if (methods.isEmpty)
          const _PaymentNotice(
            icon: Icons.info_outline,
            color: AppColors.grey600,
            message:
                'Belum ada metode pembayaran aktif. Pesanan belum bisa dibuat '
                'sampai metode pembayaran tersedia.',
          )
        else ...[
          if (current != null) ...[
            Builder(
              builder: (context) {
                // Angka server (calculate) lebih berwenang daripada hitungan
                // lokal; lokal hanya dipakai saat server belum menjawab.
                final calc = calculation;
                final fee = calc?.fee ?? current.feeFor(amount);
                final total = calc?.total ?? (amount + fee);
                return Text(
                  fee == 0
                      ? '${current.title} • tanpa biaya admin'
                      : '${current.title} • biaya admin ${formatRupiah(fee)} '
                            '→ bayar ${formatRupiah(total)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.warning),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: methods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _PayCard(
                method: methods[i],
                amount: amount,
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Pesanan dibuat dulu, tagihannya menyusul di halaman berikutnya —
          // jangan sampai pembeli mengira uangnya sudah ditarik di sini.
          const _PaymentNotice(
            icon: Icons.info_outline,
            color: AppColors.grey600,
            message:
                'Setelah menekan Pesan, Anda diarahkan ke halaman pembayaran. '
                'Tagihan berlaku 15 menit.',
          ),
        ],
      ],
    );
  }
}

/// Baris pemberitahuan kecil di bagian pembayaran.
class _PaymentNotice extends StatelessWidget {
  const _PaymentNotice({
    required this.icon,
    required this.color,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.creamSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: AppColors.grey600),
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel ?? 'Coba lagi',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PayCard extends StatelessWidget {
  const _PayCard({
    required this.method,
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final int amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 128,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.gold500 : AppColors.grey100,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo dari server bila ada; bila kosong pakai ikon per jenis.
            SizedBox(
              height: 26,
              child: method.hasLogo
                  ? Image.network(
                      method.file,
                      height: 26,
                      alignment: Alignment.centerLeft,
                      errorBuilder: (_, __, ___) => Icon(
                        _payIcon(method),
                        color: AppColors.textDark,
                        size: 26,
                      ),
                    )
                  : Icon(_payIcon(method), color: AppColors.textDark, size: 26),
            ),
            const Spacer(),
            Text(
              method.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              method.hasFee
                  ? '+ ${formatRupiah(method.feeFor(amount))}'
                  : 'Tanpa biaya',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppColors.grey600),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.items});

  final List<ServerCartItem> items;

  @override
  Widget build(BuildContext context) {
    final count = items.fold<int>(0, (s, e) => s + e.quantity);
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                  size: 18,
                  color: AppColors.maroon700,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pesan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  'Total $count Items',
                  style: TextStyle(fontSize: 12, color: AppColors.grey600),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Text(
                    '${item.quantity} x',
                    style: TextStyle(fontSize: 13, color: AppColors.grey600),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Text(
                    formatRupiah(item.subtotal),
                    style: const TextStyle(color: AppColors.textDark),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// BANNER PERINGATAN + INSTANT DELIVERY (delivery)
// =============================================================================

class _WarningBanner extends StatelessWidget {
  const _WarningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 22,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Pastikan nomor kamu dapat dihubungi oleh driver/tim kami',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstantDeliveryInfo extends StatelessWidget {
  const _InstantDeliveryInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.success, width: 3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Instant Delivery',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatRupiah(Fees.instantDelivery),
                  style: TextStyle(fontSize: 13, color: AppColors.grey600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Estimasi Pengiriman ${Fees.deliveryEta}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// RINCIAN HARGA
// =============================================================================

/// Catatan untuk outlet — dikirim sebagai `keterangan` saat checkout.
class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 2,
      maxLength: 255, // batas server
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Catatan untuk outlet (opsional)',
        hintText: 'cth: Tolong dipisah bungkusnya',
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.grey300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.maroon700, width: 1.5),
        ),
      ),
    );
  }
}

class _DeliveryUnavailableNotice extends StatelessWidget {
  const _DeliveryUnavailableNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 18,
            color: AppColors.warning,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pengantaran belum tersedia. Untuk sekarang pesanan hanya bisa '
              'diambil di outlet — kembali dan pilih Pickup.',
              style: TextStyle(fontSize: 12, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rincian harga — seluruhnya dari `.../calculate`.
///
/// Hanya tiga baris, dan ketiganya konsisten satu sama lain
/// ([amount] + [fee] = [total]). Biaya lokal seperti kantung belanja & poin
/// sengaja tidak ikut di sini karena server tidak mengetahuinya.
/// Menegaskan bagian mana dari total yang sudah pasti, dan apa yang belum
/// diperhitungkan server.
// class _TotalNote extends StatelessWidget {
//   const _TotalNote({required this.orderTotal});

//   final int orderTotal;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Icon(Icons.info_outline, size: 14, color: AppColors.grey400),
//         const SizedBox(width: 6),
//         Expanded(
//           child: Text(
//             'Total sudah termasuk biaya admin, sesuai hitungan server.',
//             style: TextStyle(fontSize: 11, color: AppColors.grey600),
//           ),
//         ),
//       ],
//     );
//   }
// }

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.amount,
    required this.fee,
    required this.total,
  });

  /// `amount` — harga sebelum biaya admin.
  final int amount;

  /// `fee` — biaya admin hasil hitungan server.
  final int fee;

  /// `total` — yang dibayar pembeli.
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row('Subtotal', formatRupiah(amount)),
        const Divider(height: 20),
        _row('Biaya Admin', formatRupiah(fee)),
        const Divider(height: 20),
        _row('Total Pembayaran', formatRupiah(total), bold: true),
      ],
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? AppColors.textDark : AppColors.grey600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// BILAH BAWAH
// =============================================================================

class _CheckoutBottomBar extends StatelessWidget {
  const _CheckoutBottomBar({
    required this.total,
    required this.showSchedule,
    required this.scheduleLabel,
    required this.onSchedule,
    required this.onPay,
    this.loading = false,
  });

  final int total;
  final bool showSchedule;
  final String? scheduleLabel;
  final VoidCallback onSchedule;

  /// Null = tombol dimatikan (mis. delivery belum didukung API).
  final VoidCallback? onPay;

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.grey100)),
        ),
        child: Row(
          children: [
            if (showSchedule) ...[
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: onSchedule,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(scheduleLabel ?? 'Jadwalkan'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.maroon700,
                      side: const BorderSide(color: AppColors.maroon700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 6,
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: loading ? null : onPay,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.maroon700,
                    disabledBackgroundColor: AppColors.grey300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          // Menekan tombol ini baru membuat pesanan; uang
                          // ditagih di halaman pembayaran berikutnya.
                          child: Text(
                            'Pesan - ${formatRupiah(total)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MODAL: Keluar Halaman Ini?
// =============================================================================

class _ExitDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.help_outline, size: 32, color: AppColors.textDark),
            const SizedBox(height: 12),
            const Text(
              'Keluar Halaman Ini?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tinggal selangkah lagi untuk menyelesaikan pemesanan loh.',
              style: TextStyle(color: AppColors.grey600),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.maroon700,
                  side: const BorderSide(color: AppColors.maroon700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Keluar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, false),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Lanjutkan Bayar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MODAL: Lihat Semua pembayaran
// =============================================================================

class _AllPaymentsSheet extends StatelessWidget {
  const _AllPaymentsSheet({required this.methods, required this.selected});

  final List<PaymentMethod> methods;
  final int selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Pilih Metode Pembayaran',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          for (int i = 0; i < methods.length; i++)
            ListTile(
              leading: Icon(_payIcon(methods[i]), color: AppColors.textDark),
              title: Text(methods[i].title),
              subtitle: Text(
                methods[i].provider.isEmpty
                    ? methods[i].value
                    : '${methods[i].value} • ${methods[i].provider}',
              ),
              trailing: i == selected
                  ? const Icon(Icons.check_circle, color: AppColors.success)
                  : null,
              onTap: () => Navigator.pop(context, i),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SchedulePickupSheet extends StatefulWidget {
  const _SchedulePickupSheet();

  @override
  State<_SchedulePickupSheet> createState() => _SchedulePickupSheetState();
}

class _SchedulePickupSheetState extends State<_SchedulePickupSheet> {
  /// Awal tiap slot, dalam jam dinding WITA — jam ambil mengacu pada jam
  /// outlet, bukan jam perangkat pembeli.
  late final List<DateTime> _starts = _buildStarts();
  int _index = 0;

  List<DateTime> _buildStarts() {
    final now = nowWita();
    // Bulatkan ke kelipatan 15 menit berikutnya.
    final add = 15 - (now.minute % 15);
    final start = now
        .add(Duration(minutes: add == 0 ? 15 : add))
        .copyWith(second: 0, millisecond: 0, microsecond: 0);
    return [for (var i = 0; i < 16; i++) start.add(Duration(minutes: 15 * i))];
  }

  /// Label satu slot, mis. `15:00 - 15:15`.
  String _label(int i) {
    final s = _starts[i];
    final e = s.add(const Duration(minutes: 15));
    return '${formatJamWita(s)} - ${formatJamWita(e)}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.schedule, size: 30, color: AppColors.textDark),
            const SizedBox(height: 8),
            const Text(
              'Jadwalkan Pickup',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Hari Ini, ${_label(_index)} WITA',
              style: TextStyle(color: AppColors.grey600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListWheelScrollView.useDelegate(
                itemExtent: 44,
                perspective: 0.004,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) => setState(() => _index = i),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _starts.length,
                  builder: (context, i) => Center(
                    child: Text(
                      _label(i),
                      style: TextStyle(
                        fontSize: i == _index ? 20 : 16,
                        fontWeight: i == _index
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: i == _index
                            ? AppColors.textDark
                            : AppColors.grey400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, 'now'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.maroon700,
                  side: const BorderSide(color: AppColors.maroon700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Pickup Sekarang',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _starts[_index]),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Lanjut',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HELPER
// =============================================================================

BoxDecoration _cardDecoration() => BoxDecoration(
  color: AppColors.white,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: AppColors.grey100),
  boxShadow: [
    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
  ],
);
