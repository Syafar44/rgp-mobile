import 'package:flutter/material.dart';

import '../core/network/api_error.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatter.dart';
import '../data/cart_store.dart';
import '../data/models/product.dart';
import '../data/outlet_store.dart';
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

    setState(() => _adding = true);
    try {
      await cartStore.add(outletId, menuId: menuId, quantity: _qty);
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
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: _AddBar(
        qty: _qty,
        total: p.effectivePrice * _qty,
        loading: _adding,
        onMinus: () => setState(() => _qty = _qty > 1 ? _qty - 1 : 1),
        onPlus: () => setState(() => _qty++),
        onAdd: _adding ? null : _addToCart,
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
                  onPressed: onAdd,
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
                          child: Text(
                            '+ Keranjang  ${formatRupiah(total)}',
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
