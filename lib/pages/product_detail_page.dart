import 'package:flutter/material.dart';

import '../core/network/api_error.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatter.dart';
import '../data/cart_store.dart';
import '../data/models/order.dart';
import '../data/models/product.dart';
import '../data/order_store.dart';
import '../data/outlet_store.dart';
import '../widgets/ongoing_order_guard.dart';
import '../widgets/verified_email_guard.dart';
import '../widgets/product_card.dart';

/// Halaman detail produk: hero gambar, deskripsi, paket hemat (upsell),
/// catatan tambahan, dan bilah bawah untuk menambah ke keranjang.
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _qty = 1;

  /// True selama permintaan tambah-ke-keranjang berlangsung (cegah dobel-tap).
  bool _adding = false;

  /// Varian pilihan untuk menu paket: `menu_id` → jumlah **per satu paket**
  /// (server yang mengalikannya dengan jumlah paket).
  final Map<int, int> _variantQty = {};

  bool get _isPackage => widget.product.isPackage;

  int get _variantTotal => _variantQty.values.fold(0, (a, b) => a + b);

  /// Paket wajib berisi varian sebanyak `max_qty` — tidak boleh kurang/lebih.
  bool get _variantsComplete =>
      !_isPackage || _variantTotal == widget.product.maxQty;

  void _setVariant(int menuId, int qty) {
    setState(() {
      if (qty <= 0) {
        _variantQty.remove(menuId);
      } else {
        _variantQty[menuId] = qty;
      }
    });
  }

  Future<void> _addToCart() async {
    final outletId = outletStore.outletId;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (outletId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pilih outlet Panglima dulu sebelum memesan.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final menuId = int.tryParse(widget.product.id);
    if (menuId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Menu ini belum bisa dipesan.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!_variantsComplete) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Pilih tepat ${widget.product.maxQty} varian untuk paket ini.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Email belum terverifikasi → keranjang pun tidak boleh diisi.
    if (!await ensureEmailVerified(context) || !mounted) return;

    // Satu pesanan pada satu waktu — keranjang pun tidak boleh diisi selama
    // masih ada pesanan berjalan, supaya pembeli tidak menumpuk belanjaan
    // yang ujungnya tertahan di checkout.
    if (!await ensureNoOngoingOrder(context, refresh: false) || !mounted) {
      return;
    }

    setState(() => _adding = true);
    try {
      await cartStore.add(
        outletId,
        menuId: menuId,
        quantity: _qty,
        // Paket wajib mengirim props; qty di sini per SATU paket.
        props: _isPackage
            ? [
                for (final e in _variantQty.entries)
                  {'menu_id': e.key, 'quantity': e.value},
              ]
            : null,
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${widget.product.name} ditambahkan ke keranjang'),
          duration: const Duration(seconds: 1),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _adding = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), duration: const Duration(seconds: 2)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _adding = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Gagal menambahkan ke keranjang. Coba lagi.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Hero(product: p)),
          SliverToBoxAdapter(child: _Header(product: p)),
          if (_isPackage)
            SliverToBoxAdapter(
              child: _VariantPicker(
                product: p,
                selected: _variantQty,
                total: _variantTotal,
                onChanged: _setVariant,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: _AddBar(
        qty: _qty,
        total: p.effectivePrice * _qty,
        loading: _adding,
        onMinus: () => setState(() => _qty = _qty > 1 ? _qty - 1 : 1),
        onPlus: () => setState(() => _qty++),
        onAdd: (_adding || !_variantsComplete) ? null : _addToCart,
      ),
    );
  }
}

// =============================================================================
// PILIH VARIAN PAKET
// =============================================================================

/// Pemilih isi paket. Jumlah yang dipilih harus tepat `max_qty` per satu paket;
/// server yang mengalikannya dengan jumlah paket yang dipesan.
class _VariantPicker extends StatelessWidget {
  const _VariantPicker({
    required this.product,
    required this.selected,
    required this.total,
    required this.onChanged,
  });

  final Product product;
  final Map<int, int> selected;
  final int total;
  final void Function(int menuId, int qty) onChanged;

  @override
  Widget build(BuildContext context) {
    final max = product.maxQty;
    final complete = total == max;
    final sisa = max - total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pilih Isi Paket',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (complete ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$total / $max',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: complete ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            complete
                ? 'Pilihan lengkap. Jumlah ini berlaku untuk satu paket.'
                : sisa > 0
                ? 'Pilih $sisa varian lagi untuk satu paket.'
                : 'Kurangi ${-sisa} varian — melebihi isi paket.',
            style: TextStyle(fontSize: 12, color: AppColors.grey600),
          ),
          const SizedBox(height: 12),
          for (final v in product.variants)
            _VariantRow(
              variant: v,
              qty: selected[v.id] ?? 0,
              canAdd: total < max,
              onChanged: (qty) => onChanged(v.id, qty),
            ),
          if (product.variants.isEmpty)
            Text(
              'Varian paket belum tersedia dari server.',
              style: TextStyle(fontSize: 12, color: AppColors.grey600),
            ),
        ],
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  const _VariantRow({
    required this.variant,
    required this.qty,
    required this.canAdd,
    required this.onChanged,
  });

  final MenuVariant variant;
  final int qty;
  final bool canAdd;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              variant.title,
              style: const TextStyle(fontSize: 14, color: AppColors.textDark),
            ),
          ),
          IconButton(
            onPressed: qty > 0 ? () => onChanged(qty - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: AppColors.maroon700,
            iconSize: 22,
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: canAdd ? () => onChanged(qty + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.maroon700,
            iconSize: 22,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// HERO GAMBAR + tombol back & share
// =============================================================================

class _Hero extends StatelessWidget {
  const _Hero({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        SizedBox(
          height: 260,
          width: double.infinity,
          child: ProductImage(imageUrl: product.imageUrl),
        ),
        Positioned(
          top: topPad + 8,
          left: 12,
          child: _CircleButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.pop(context),
          ),
        ),
        Positioned(
          top: topPad + 8,
          right: 12,
          child: _CircleButton(
            icon: Icons.ios_share,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bagikan produk (dummy)'),
                duration: Duration(seconds: 1),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 22, color: AppColors.textDark),
        ),
      ),
    );
  }
}

// =============================================================================
// NAMA + HARGA + DESKRIPSI
// =============================================================================

class _Header extends StatelessWidget {
  const _Header({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRupiah(product.effectivePrice),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (product.isPromo)
                    Text(
                      formatRupiah(product.price),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.grey400,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            product.description,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.grey600,
            ),
          ),
        ],
      ),
    );
  }
}
// =============================================================================
// BILAH BAWAH: stepper + tombol tambah keranjang
// =============================================================================

class _AddBar extends StatelessWidget {
  const _AddBar({
    required this.qty,
    required this.total,
    required this.loading,
    required this.onMinus,
    required this.onPlus,
    required this.onAdd,
  });

  final int qty;
  final int total;
  final bool loading;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    // Selama ada pesanan berjalan, keranjang tidak boleh diisi. Ditampilkan di
    // tombolnya langsung — pembeli tahu sebelum menekan, bukan sesudah.
    return ValueListenableBuilder<List<Order>>(
      valueListenable: orderStore.active,
      builder: (context, orders, _) => _bar(terkunci: orders.isNotEmpty),
    );
  }

  Widget _bar({required bool terkunci}) {
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
            _Stepper(qty: qty, onMinus: onMinus, onPlus: onPlus),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: terkunci ? null : onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.maroon700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.white,
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (terkunci) ...[
                                const Icon(Icons.lock_outline, size: 16),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                terkunci
                                    ? 'Ada pesanan berjalan'
                                    : '+ Keranjang  ${formatRupiah(total)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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

/// Stepper jumlah (− n +) dengan bingkai.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.grey300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _StepBtn(icon: Icons.remove, onTap: onMinus),
          SizedBox(
            width: 28,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          _StepBtn(icon: Icons.add, onTap: onPlus),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Icon(icon, size: 20, color: AppColors.maroon700),
      ),
    );
  }
}
