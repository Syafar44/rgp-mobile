import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatter.dart';
import '../data/cart_store.dart';
import '../data/dummy/dummy_data.dart';
import '../data/models/product.dart';
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
  final TextEditingController _note = TextEditingController();

  static const int _noteMax = 100;

  /// Paket hemat sebagai upsell (produk kategori "Paket").
  late final List<Product> _upsell = DummyData.products
      .where((p) => p.category == 'Paket' && p.id != widget.product.id)
      .toList();

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _addToCart() {
    cartStore.add(widget.product, qty: _qty, note: _note.text.trim());
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.product.name} ditambahkan ke keranjang'),
        duration: const Duration(seconds: 1),
      ),
    );
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
          const SliverToBoxAdapter(child: _Gap()),
          if (_upsell.isNotEmpty) ...[
            SliverToBoxAdapter(child: _UpsellSection(items: _upsell)),
            const SliverToBoxAdapter(child: _Gap()),
          ],
          SliverToBoxAdapter(
            child: _NoteSection(
              controller: _note,
              max: _noteMax,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: _AddBar(
        qty: _qty,
        total: p.effectivePrice * _qty,
        onMinus: () => setState(() => _qty = _qty > 1 ? _qty - 1 : 1),
        onPlus: () => setState(() => _qty++),
        onAdd: _addToCart,
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
// SUPAYA KAMU HEMAT (upsell paket)
// =============================================================================

class _UpsellSection extends StatelessWidget {
  const _UpsellSection({required this.items});

  final List<Product> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Supaya kamu hemat',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ),
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
          _UpsellTile(product: items[i]),
        ],
      ],
    );
  }
}

class _UpsellTile extends StatelessWidget {
  const _UpsellTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(product: product),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: ProductImage(imageUrl: product.imageUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        formatRupiah(product.effectivePrice),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (product.isPromo) ...[
                        const SizedBox(width: 6),
                        Text(
                          formatRupiah(product.price),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.grey400,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.gold500,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// CATATAN TAMBAHAN
// =============================================================================

class _NoteSection extends StatelessWidget {
  const _NoteSection({required this.controller, required this.max});

  final TextEditingController controller;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Catatan Tambahan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                '${controller.text.characters.length}/$max',
                style: TextStyle(fontSize: 12, color: AppColors.grey400),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLength: max,
            maxLines: 3,
            minLines: 3,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                null,
            decoration: InputDecoration(
              hintText: 'Ga perlu baper',
              hintStyle: const TextStyle(color: AppColors.grey400),
              filled: true,
              fillColor: AppColors.grey100,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
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
    required this.onMinus,
    required this.onPlus,
    required this.onAdd,
  });

  final int qty;
  final int total;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onAdd;

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
                  child: FittedBox(
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

/// Pemisah abu-abu tebal antar-seksi (seperti di gambar).
class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) {
    return Container(height: 8, color: AppColors.grey100);
  }
}
