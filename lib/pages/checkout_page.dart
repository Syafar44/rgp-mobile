import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config/fees.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatter.dart';
import '../data/address_store.dart';
import '../data/cart_store.dart';
import '../data/dummy/dummy_data.dart';
import '../data/models/cart_item.dart';
import '../data/models/saved_address.dart';
import '../data/notifiers.dart';
import 'outlet_page.dart';

/// Metode pembayaran (dummy). Ikon Material dipakai sebagai pengganti logo.
typedef PayMethod = ({String name, String desc, IconData icon, Color color});

const List<PayMethod> _payMethods = [
  (
    name: 'QRIS',
    desc: 'Simpan QR dan bayar',
    icon: Icons.qr_code_2,
    color: AppColors.textDark,
  ),
  (
    name: 'ShopeePay',
    desc: 'Bayar dengan ShopeePay',
    icon: Icons.account_balance_wallet,
    color: Color(0xFFEE4D2D),
  ),
  (
    name: 'blu by BCA',
    desc: 'Cashback 40% max. 25RB',
    icon: Icons.account_balance,
    color: Color(0xFF00A9E0),
  ),
  (
    name: 'GoPay',
    desc: 'Saldo GoPay',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFF00AAD2),
  ),
  (
    name: 'OVO',
    desc: 'Saldo OVO',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFF4C2A86),
  ),
  (
    name: 'DANA',
    desc: 'Saldo DANA',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFF118EEA),
  ),
  (
    name: 'Tunai',
    desc: 'Bayar di kasir',
    icon: Icons.payments_outlined,
    color: AppColors.success,
  ),
];

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
  bool _kantungBelanja = false;
  int _payMethod = 0;
  String? _scheduleLabel; // null = Pickup Sekarang

  bool get _isDelivery => widget.isDelivery;

  // --- Rincian harga --------------------------------------------------------

  int get _subtotal => cartStore.total;
  int get _deliveryFee => _isDelivery ? Fees.instantDelivery : 0;
  int get _takeAway => _isDelivery
      ? Fees.takeAwayCharge
      : (_kantungBelanja ? Fees.kantungBelanja : 0);
  int get _cashback => Fees.loyaltyCashback(_subtotal);
  int get _beforeRedeem => _subtotal + _deliveryFee + _takeAway;
  int get _redeem => _redeemPoints ? math.min(DummyData.poin, _beforeRedeem) : 0;
  int get _total => _beforeRedeem - _redeem;

  // --- Aksi -----------------------------------------------------------------

  /// Konfirmasi keluar dari halaman. Mengembalikan true bila boleh keluar.
  Future<bool> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ExitDialog(),
    );
    return leave ?? false;
  }

  Future<void> _showAllPayments() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => _AllPaymentsSheet(selected: _payMethod),
    );
    if (picked != null) setState(() => _payMethod = picked);
  }

  Future<void> _schedulePickup() async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _SchedulePickupSheet(),
    );
    // Sentinel 'now' berarti "Pickup Sekarang".
    if (result != null) {
      setState(() => _scheduleLabel = result == 'now' ? null : result);
    }
  }

  void _pay() {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final method = _payMethods[_payMethod].name;
    cartStore.clear();
    navigator.popUntil((r) => r.isFirst);
    selectedPageNotifier.value = 3; // tab History
    messenger.showSnackBar(
      SnackBar(
        content: Text('Pesanan dibayar via $method (dummy)'),
        duration: const Duration(seconds: 2),
      ),
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
        body: ValueListenableBuilder<List<CartItem>>(
          valueListenable: cartStore.notifier,
          builder: (context, items, _) {
            if (items.isEmpty) {
              return const Center(child: Text('Keranjang kosong'));
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _isDelivery
                    ? _RouteCard(outlet: widget.outlet)
                    : _PickupInfoCard(outlet: widget.outlet),
                const SizedBox(height: 20),
                _PointsRedeem(
                  redeem: _redeemPoints,
                  onChanged: (v) => setState(() => _redeemPoints = v),
                ),
                const SizedBox(height: 20),
                _PaymentSection(
                  selected: _payMethod,
                  onSelect: (i) => setState(() => _payMethod = i),
                  onSeeAll: _showAllPayments,
                ),
                const SizedBox(height: 20),
                _OrderSummary(items: items),
                if (_isDelivery) ...[
                  const SizedBox(height: 12),
                  const _WarningBanner(),
                  const SizedBox(height: 12),
                  const _InstantDeliveryInfo(),
                ] else ...[
                  const SizedBox(height: 12),
                  _KantungBelanja(
                    checked: _kantungBelanja,
                    onChanged: (v) => setState(() => _kantungBelanja = v),
                  ),
                ],
                const SizedBox(height: 12),
                const _VoucherRow(),
                const SizedBox(height: 16),
                _Breakdown(
                  subtotal: _subtotal,
                  deliveryFee: _deliveryFee,
                  takeAway: _takeAway,
                  isDelivery: _isDelivery,
                  cashback: _cashback,
                  redeem: _redeem,
                  total: _total,
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: _CheckoutBottomBar(
          total: _total,
          showSchedule: !_isDelivery,
          scheduleLabel: _scheduleLabel,
          onSchedule: _schedulePickup,
          onPay: _pay,
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
  const _PickupInfoCard({required this.outlet});

  final Outlet outlet;

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: AppColors.grey600)),
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
                  child: const Icon(Icons.stars_rounded,
                      color: AppColors.gold500, size: 22),
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
                        style:
                            TextStyle(fontSize: 12, color: AppColors.grey600),
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
    required this.selected,
    required this.onSelect,
    required this.onSeeAll,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(height: 4),
        Text(
          '${_payMethods[selected].name} • ${_payMethods[selected].desc}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: AppColors.warning),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _payMethods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _PayCard(
              method: _payMethods[i],
              selected: i == selected,
              onTap: () => onSelect(i),
            ),
          ),
        ),
      ],
    );
  }
}

class _PayCard extends StatelessWidget {
  const _PayCard({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PayMethod method;
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
            Icon(method.icon, color: method.color, size: 26),
            const Spacer(),
            Text(
              method.name,
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
              method.desc,
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

// =============================================================================
// PESAN (ringkasan)
// =============================================================================

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.items});

  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    final count = items.fold<int>(0, (s, e) => s + e.qty);
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined,
                    size: 18, color: AppColors.maroon700),
                const SizedBox(width: 8),
                const Text('Pesan',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
                    '${item.qty} x',
                    style: TextStyle(fontSize: 13, color: AppColors.grey600),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.product.name,
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
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 22),
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
// KANTUNG BELANJA (pickup)
// =============================================================================

class _KantungBelanja extends StatelessWidget {
  const _KantungBelanja({required this.checked, required this.onChanged});

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.maroon700,
            ),
            const Expanded(
              child: Text(
                'Kantung Belanja',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Text(
              formatRupiah(Fees.kantungBelanja),
              style: TextStyle(color: AppColors.grey600),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// VOUCHER
// =============================================================================

class _VoucherRow extends StatelessWidget {
  const _VoucherRow();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan kode voucher (dummy)'),
          duration: Duration(seconds: 1),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.yellow50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold500),
        ),
        child: Row(
          children: [
            const Icon(Icons.confirmation_number_outlined,
                color: AppColors.maroon700),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Pakai Kode Voucher',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gold500),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// RINCIAN HARGA
// =============================================================================

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.subtotal,
    required this.deliveryFee,
    required this.takeAway,
    required this.isDelivery,
    required this.cashback,
    required this.redeem,
    required this.total,
  });

  final int subtotal;
  final int deliveryFee;
  final int takeAway;
  final bool isDelivery;
  final int cashback;
  final int redeem;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row('Subtotal', formatRupiah(subtotal)),
        if (isDelivery) ...[
          const Divider(height: 20),
          _row('Delivery Fee', formatRupiah(deliveryFee)),
          const Divider(height: 20),
          _row('Take Away Charge', formatRupiah(takeAway)),
        ] else if (takeAway > 0) ...[
          const Divider(height: 20),
          _row('Kantung Belanja', formatRupiah(takeAway)),
        ],
        if (redeem > 0) ...[
          const Divider(height: 20),
          _row('Redeem Points', '- ${formatRupiah(redeem)}',
              valueColor: AppColors.success),
        ],
        const Divider(height: 20),
        _row('Loyalty Cashback', '+ $cashback', valueColor: AppColors.success),
        const Divider(height: 20),
        _row('Total Pembayaran', formatRupiah(total), bold: true),
      ],
    );
  }

  Widget _row(String label, String value,
      {bool bold = false, Color? valueColor}) {
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
  });

  final int total;
  final bool showSchedule;
  final String? scheduleLabel;
  final VoidCallback onSchedule;
  final VoidCallback onPay;

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
                  onPressed: onPay,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.maroon700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Bayar - ${formatRupiah(total)}',
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
                child: const Text('Keluar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
                child: const Text('Lanjutkan Bayar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
  const _AllPaymentsSheet({required this.selected});

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
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Metode Pembayaran',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          for (int i = 0; i < _payMethods.length; i++)
            ListTile(
              leading: Icon(_payMethods[i].icon, color: _payMethods[i].color),
              title: Text(_payMethods[i].name),
              subtitle: Text(_payMethods[i].desc),
              trailing: Icon(
                i == selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: i == selected ? AppColors.maroon700 : AppColors.grey300,
              ),
              onTap: () => Navigator.pop(context, i),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// =============================================================================
// MODAL: Jadwalkan Pickup
// =============================================================================

class _SchedulePickupSheet extends StatefulWidget {
  const _SchedulePickupSheet();

  @override
  State<_SchedulePickupSheet> createState() => _SchedulePickupSheetState();
}

class _SchedulePickupSheetState extends State<_SchedulePickupSheet> {
  late final List<String> _slots = _buildSlots();
  int _index = 0;

  static String _two(int n) => n.toString().padLeft(2, '0');

  List<String> _buildSlots() {
    final now = DateTime.now();
    // Bulatkan ke kelipatan 15 menit berikutnya.
    final add = 15 - (now.minute % 15);
    var start = now.add(Duration(minutes: add == 0 ? 15 : add));
    final list = <String>[];
    for (var i = 0; i < 16; i++) {
      final s = start.add(Duration(minutes: 15 * i));
      final e = s.add(const Duration(minutes: 15));
      list.add('${_two(s.hour)}:${_two(s.minute)} - '
          '${_two(e.hour)}:${_two(e.minute)}');
    }
    return list;
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
              'Hari Ini, ${_slots[_index]}',
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
                  childCount: _slots.length,
                  builder: (context, i) => Center(
                    child: Text(
                      _slots[i],
                      style: TextStyle(
                        fontSize: i == _index ? 20 : 16,
                        fontWeight:
                            i == _index ? FontWeight.bold : FontWeight.normal,
                        color:
                            i == _index ? AppColors.textDark : AppColors.grey400,
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
                child: const Text('Pickup Sekarang',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _slots[_index]),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Lanjut',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
