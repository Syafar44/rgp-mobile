import 'package:flutter/material.dart';

import '../core/config/app_features.dart';
import '../core/config/fees.dart';
import '../core/network/api_error.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatter.dart';
import '../core/utils/wita.dart';
import '../data/address_store.dart';
import '../data/cart_store.dart';
import '../data/models/cart.dart';
import '../data/models/saved_address.dart';
import '../data/notifiers.dart';
import '../data/outlet_store.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/product_card.dart';
import 'address_page.dart';
import 'checkout_page.dart';
import '../widgets/network_guard.dart';
import '../widgets/verified_email_guard.dart';
import '../widgets/ongoing_order_guard.dart';
import 'outlet_page.dart';
import '../widgets/outlet_switch.dart';

/// Halaman Konfirmasi Pesanan (keranjang).
///
/// Metode hanya Pickup atau Delivery (tanpa Dine-In). Isi keranjang diambil
/// dari server (`/pos/app/v1/outlets/:id/cart`) via [cartStore], per-outlet.
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  /// 0 = Pickup, 1 = Delivery.
  int _method = 0;

  /// Peringatan stok dari `POST .../cart/validate`. Null = aman.
  String? _stockWarning;

  @override
  void initState() {
    super.initState();
    outletStore.selected.addListener(_onOutletChanged);
    // Muat keranjang server untuk outlet terpilih saat halaman dibuka.
    final id = outletStore.outletId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await cartStore.loadFor(id);
        await _checkStock(id);
      });
    }
  }

  /// Cek ulang stok seluruh keranjang di server.
  ///
  /// Dokumen menganjurkan memanggil ini saat layar konfirmasi dibuka, supaya
  /// pembeli tahu lebih awal — sebelum memilih jam ambil & mengisi catatan —
  /// ketimbang baru tertahan saat checkout.
  Future<void> _checkStock(int outletId) async {
    if (cartStore.isEmpty) {
      if (mounted) setState(() => _stockWarning = null);
      return;
    }
    try {
      final available = await cartStore.validate(outletId);
      if (!mounted) return;
      setState(() {
        _stockWarning = available
            ? null
            : 'Stok sedang tidak tersedia untuk sebagian pesanan. Kurangi '
                  'jumlah atau pilih menu lain.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // Keranjang kosong/kedaluwarsa bukan galat — tampilan kosong sudah
      // menangani keadaan itu.
      setState(() => _stockWarning = cartStore.isEmpty ? null : e.message);
    } catch (_) {
      // Gagal jaringan saat pengecekan awal tidak perlu menghalangi pembeli;
      // checkout tetap memeriksa stok lagi di server.
      if (mounted) setState(() => _stockWarning = null);
    }
  }

  @override
  void dispose() {
    outletStore.selected.removeListener(_onOutletChanged);
    super.dispose();
  }

  void _onOutletChanged() {
    final id = outletStore.outletId;
    if (id == null) return;
    cartStore.loadFor(id).then((_) => _checkStock(id));
  }

  /// Ubah jumlah satu baris keranjang di server; tampilkan pesan bila gagal.
  Future<void> _changeQty(ServerCartItem item, int newQty) async {
    final id = outletStore.outletId;
    if (id == null) return;
    // Menambah jumlah = menambah isi keranjang, jadi ikut ditahan dua aturan:
    // email harus sudah terverifikasi, dan tidak boleh ada pesanan berjalan.
    // Mengurangi & menghapus tetap boleh — pembeli harus bisa mengosongkan
    // keranjangnya dalam keadaan apa pun.
    if (newQty > item.quantity) {
      if (!await ensureEmailVerified(context) || !mounted) return;
      if (!await ensureNoOngoingOrder(context, refresh: false) || !mounted) {
        return;
      }
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await cartStore.setQty(id, item.id, newQty);
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Gagal memperbarui keranjang. Coba lagi.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Pilih / ganti outlet sumber (disimpan di [outletStore], lintas halaman).
  Future<void> _pickOutlet() async {
    final selected = await Navigator.push<Outlet>(
      context,
      MaterialPageRoute(builder: (_) => const OutletPage()),
    );
    if (selected != null && mounted) await switchOutlet(context, selected);
  }

  /// Pilih / ubah lokasi pengiriman (buka halaman Alamat Pengiriman).
  Future<void> _pickAddress() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const AddressPage()),
    );
    // Alamat aktif otomatis ter-update lewat addressStore.notifier.
  }

  /// Total keranjang + ongkir Instant Delivery (bila metode Delivery).
  int get _payableTotal =>
      cartStore.total + (_method == 1 ? Fees.instantDelivery : 0);

  void _addMoreItems() {
    Navigator.pop(context);
    selectedPageNotifier.value = 1; // tab Menu
  }

  /// Konfirmasi metode (Pickup/Delivery) lalu lanjut ke halaman Checkout.
  Future<void> _goToCheckout() async {
    // Email belum terverifikasi → tidak boleh membuat pesanan.
    // Menjelajah menu & mengisi keranjang tetap bebas.
    if (!await ensureEmailVerified(context) || !mounted) return;

    // Jaringan diperiksa paling awal: penjaga "satu pesanan" di bawahnya juga
    // bergantung pada server, jadi kalau koneksinya buruk ia gagal terbuka
    // dan justru meloloskan pesanan kedua.
    if (!await ensureNetworkReady(context) || !mounted) return;

    // Satu pesanan pada satu waktu — ditahan di sini, sebelum pembeli repot
    // mengisi jam ambil, catatan, dan memilih pembayaran.
    if (!await ensureNoOngoingOrder(context) || !mounted) return;

    final outlet = outletStore.outlet;
    if (outlet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih outlet Panglima dulu.'),
          duration: Duration(seconds: 2),
        ),
      );
      _pickOutlet();
      return;
    }
    // Cek stok sekali lagi tepat sebelum lanjut — lebih baik tertahan di sini
    // daripada gagal saat checkout setelah mengisi catatan & jam ambil.
    await _checkStock(outlet.id);
    if (!mounted) return;
    if (_stockWarning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_stockWarning!),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _MethodConfirmSheet(isDelivery: _method == 1, outlet: outlet),
    );
    if (confirmed != true || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(isDelivery: _method == 1, outlet: outlet),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Konfirmasi Pesanan'),
      body: ValueListenableBuilder<ServerCart>(
        valueListenable: cartStore.cart,
        builder: (context, cart, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: cartStore.loading,
            builder: (context, loading, _) {
              if (cart.isEmpty) {
                if (loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _EmptyCart(onBrowse: _addMoreItems);
              }
              return _cartBody(cart);
            },
          );
        },
      ),
      bottomNavigationBar: ValueListenableBuilder<ServerCart>(
        valueListenable: cartStore.cart,
        builder: (context, cart, _) {
          if (cart.isEmpty) return const SizedBox.shrink();
          return _CheckoutBar(total: _payableTotal, onPay: _goToCheckout);
        },
      ),
    );
  }

  /// Peringatan stok dari `cart/validate`.
  ///
  /// Server tidak pernah menyebut bahan apa yang kurang, dan jatah stok
  /// aplikasi memang hanya sebagian dari stok outlet — jadi pesan ini bisa
  /// muncul walau outlet terlihat masih punya barang.
  Widget _stockWarningBox(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.inventory_2_outlined,
          size: 18,
          color: AppColors.warning,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: AppColors.textDark),
          ),
        ),
      ],
    ),
  );

  /// Pengingat masa berlaku keranjang server (30 menit, diperpanjang tiap
  /// aktivitas). Ditulis dalam WITA mengikuti jam outlet.
  Widget _expiryNote(DateTime expiresAt) => Row(
    children: [
      const Icon(Icons.timer_outlined, size: 14, color: AppColors.grey400),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          'Keranjang berlaku sampai ${formatJamWita(toWita(expiresAt))} WITA.',
          style: TextStyle(fontSize: 12, color: AppColors.grey600),
        ),
      ),
    ],
  );

  Widget _cartBody(ServerCart cart) {
    return Column(
      children: [
        _MethodTabs(
          active: _method,
          onChanged: (i) => setState(() => _method = i),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (_stockWarning != null) ...[
                _stockWarningBox(_stockWarning!),
                const SizedBox(height: 12),
              ],
              if (cart.expiresAt != null) ...[
                _expiryNote(cart.expiresAt!),
                const SizedBox(height: 12),
              ],
              // Kartu outlet sumber (sama untuk Pickup & Delivery).
              ValueListenableBuilder<Outlet?>(
                valueListenable: outletStore.selected,
                builder: (context, outlet, _) =>
                    _PickupCard(outlet: outlet, onChange: _pickOutlet),
              ),
              if (_method == 1) ...[
                const SizedBox(height: 12),
                // Lokasi pengiriman kita.
                _DeliveryCard(onChange: _pickAddress),
                const SizedBox(height: 12),
                // Muncul setelah alamat terpilih: upsell + Instant Delivery.
                _OngkirUpsellBanner(subtotal: cart.total),
                const SizedBox(height: 12),
                const _InstantDeliveryRow(),
              ],
              const SizedBox(height: 20),
              _PesanHeader(onAdd: _addMoreItems),
              const SizedBox(height: 12),
              for (final item in cart.items) ...[
                _OrderItemCard(item: item, onQty: _changeQty),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TAB METODE (Pickup / Delivery)
// =============================================================================

class _MethodTabs extends StatelessWidget {
  const _MethodTabs({required this.active, required this.onChanged});

  final int active;
  final ValueChanged<int> onChanged;

  /// Index tab Delivery pada [_methods].
  static const int _deliveryIndex = 1;

  static const List<({String title, String subtitle})> _methods = [
    (title: 'Pickup', subtitle: 'Order & ambil di outlet'),
    (title: 'Delivery', subtitle: 'Pesanan diantar ke alamat'),
  ];

  /// Subtitle tab, dengan keterangan terkunci bila fiturnya belum rilis.
  String _subtitle(int i) => i == _deliveryIndex && !AppFeatures.delivery
      ? AppFeatures.segeraHadir
      : _methods[i].subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.grey100)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < _methods.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Delivery terkunci selama belum ada endpoint ongkir & alamat.
                // Sebelumnya tab ini bisa dipilih tapi tombol Pesan-nya mati di
                // halaman berikutnya — pembeli baru tahu setelah mengisi
                // segalanya.
                onTap: i == _deliveryIndex && !AppFeatures.delivery
                    ? null
                    : () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == active
                            ? AppColors.maroon700
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _methods[i].title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: i == active
                                  ? AppColors.maroon700
                                  : AppColors.grey400,
                            ),
                          ),
                          if (i == _deliveryIndex && !AppFeatures.delivery) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.lock_outline,
                              size: 13,
                              color: AppColors.grey400,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(i),
                        style: TextStyle(
                          fontSize: 11,
                          color: i == active
                              ? AppColors.grey600
                              : AppColors.grey400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// KARTU LOKASI (outlet pickup / alamat delivery)
// =============================================================================

class _PickupCard extends StatelessWidget {
  const _PickupCard({required this.outlet, required this.onChange});

  final Outlet? outlet;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final o = outlet;
    return _LocationShell(
      icon: Icons.storefront,
      title: o == null ? 'Pilih Outlet Panglima' : 'Outlet: ${o.name}',
      subtitle: o == null
          ? 'Ketuk "Ubah" untuk pilih outlet terdekat'
          : o.address,
      onChange: onChange,
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.onChange});

  final VoidCallback onChange;

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
        return _LocationShell(
          icon: Icons.location_on,
          title: addr == null
              ? 'Pilih alamat pengiriman'
              : 'Alamat: ${addr.label}',
          subtitle: addr == null
              ? 'Belum ada alamat tersimpan'
              : addr.fullAddress,
          onChange: onChange,
        );
      },
    );
  }
}

class _LocationShell extends StatelessWidget {
  const _LocationShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onChange,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey100),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.maroon700, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.grey600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onChange,
            child: const Text(
              'Ubah',
              style: TextStyle(
                color: AppColors.info,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PESAN + item keranjang
// =============================================================================

class _PesanHeader extends StatelessWidget {
  const _PesanHeader({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Pesan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Tambah Pesanan', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.info,
            side: const BorderSide(color: AppColors.info),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderItemCard extends StatelessWidget {
  const _OrderItemCard({required this.item, required this.onQty});

  final ServerCartItem item;

  /// Dipanggil saat jumlah diubah: (item, jumlah baru). ≤ 0 → baris dihapus.
  final Future<void> Function(ServerCartItem item, int newQty) onQty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatRupiah(item.subtotal),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.maroon700,
                  ),
                ),
                if (item.props.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.props
                        .map((e) => '${e.quantity}× ${e.title}')
                        .join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppColors.grey600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: ProductImage(imageUrl: item.imageUrl),
                ),
              ),
              const SizedBox(height: 10),
              _CartStepper(item: item, onQty: onQty),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stepper jumlah pada item keranjang. Perubahan dikirim ke server via [onQty].
class _CartStepper extends StatelessWidget {
  const _CartStepper({required this.item, required this.onQty});

  final ServerCartItem item;
  final Future<void> Function(ServerCartItem item, int newQty) onQty;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundStep(
          icon: item.quantity <= 1 ? Icons.delete_outline : Icons.remove,
          onTap: () => onQty(item, item.quantity - 1),
        ),
        SizedBox(
          width: 26,
          child: Text(
            '${item.quantity}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ),
        _RoundStep(
          icon: Icons.add,
          onTap: () => onQty(item, item.quantity + 1),
        ),
      ],
    );
  }
}

class _RoundStep extends StatelessWidget {
  const _RoundStep({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.maroon700),
        ),
        child: Icon(icon, size: 16, color: AppColors.maroon700),
      ),
    );
  }
}

// =============================================================================
// BILAH CHECKOUT
// =============================================================================

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.total, required this.onPay});

  final int total;
  final VoidCallback onPay;

  /// Belanja belum mencapai batas minimum.
  bool get _kurang => total < Fees.minimumBelanja;

  /// Sisa belanja yang perlu ditambahkan.
  int get _kurangnya => Fees.minimumBelanja - total;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.grey100)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Alasan tombolnya mati ditulis di atasnya, bukan disembunyikan di
            // balik ketukan: pembeli perlu tahu berapa lagi yang kurang tanpa
            // harus menebak-nebak dengan menekan tombol yang tidak merespons.
            if (_kurang) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.yellow50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.gold500,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Minimal transaksi '),
                            TextSpan(
                              text: formatRupiah(Fees.minimumBelanja),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text:
                                  '. Tambah ${formatRupiah(_kurangnya)} lagi '
                                  'untuk melanjutkan.',
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _baris(),
          ],
        ),
      ),
    );
  }

  Widget _baris() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total',
              style: TextStyle(fontSize: 11, color: AppColors.grey600),
            ),
            Text(
              formatRupiah(total),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: _kurang ? null : onPay,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.maroon700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_kurang) ...[
                    const Icon(Icons.lock_outline, size: 15),
                    const SizedBox(width: 6),
                  ],
                  const Text(
                    'Pilih Pembayaran',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// UPSELL ONGKIR + INSTANT DELIVERY (Delivery)
// =============================================================================

class _OngkirUpsellBanner extends StatelessWidget {
  const _OngkirUpsellBanner({required this.subtotal});

  final int subtotal;

  @override
  Widget build(BuildContext context) {
    final remaining = Fees.freeOngkirThreshold - subtotal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('🛵', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: remaining > 0
                ? Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Tambah ${formatRupiah(remaining)} dapat ',
                          style: TextStyle(color: AppColors.grey600),
                        ),
                        const TextSpan(
                          text: 'DISKON ONGKIR HINGGA Rp15.000',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : const Text(
                    'Yeay! Kamu dapat DISKON ONGKIR untuk pesanan ini',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _InstantDeliveryRow extends StatelessWidget {
  const _InstantDeliveryRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Kami akan mencarikan kurir tercepat untukmu.',
            style: TextStyle(fontSize: 12, color: AppColors.grey600),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.grey100),
          ),
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
        ),
      ],
    );
  }
}

// =============================================================================
// MODAL KONFIRMASI METODE (sebelum Checkout)
// =============================================================================

class _MethodConfirmSheet extends StatelessWidget {
  const _MethodConfirmSheet({required this.isDelivery, required this.outlet});

  final bool isDelivery;
  final Outlet outlet;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDelivery ? AppColors.success : AppColors.info,
                      width: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isDelivery ? 'Delivery' : 'Pickup',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              outlet.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            if (isDelivery) _DeliveryDestination() else _PickupCounterInfo(),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.maroon700,
                  side: const BorderSide(color: AppColors.gold500, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Ya, Sudah Benar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryDestination extends StatelessWidget {
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.south, size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                Text(
                  'Dikirim ke',
                  style: TextStyle(color: AppColors.grey600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              addr?.label ?? 'Pilih alamat',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            if (addr != null) ...[
              const SizedBox(height: 2),
              Text(
                addr.fullAddress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.grey600),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PickupCounterInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.point_of_sale, size: 18, color: AppColors.info),
              SizedBox(width: 8),
              Text(
                'Pickup di Counter',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ambil pesananmu di Area Pickup di dalam outlet',
          style: TextStyle(fontSize: 13, color: AppColors.warning),
        ),
      ],
    );
  }
}

// =============================================================================
// KOSONG
// =============================================================================

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🛒', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          const Text(
            'Keranjang masih kosong',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Yuk tambahkan roti gembung favoritmu.',
            style: TextStyle(color: AppColors.grey600),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onBrowse,
            icon: const Icon(Icons.bakery_dining_outlined),
            label: const Text('Lihat Menu'),
          ),
        ],
      ),
    );
  }
}
