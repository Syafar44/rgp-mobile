import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatter.dart';
import '../data/models/product.dart';
import '../pages/product_detail_page.dart';

/// Kartu produk. Dipakai di Beranda (list horizontal) & Menu (grid 2 kolom).
///
/// Beri [width] untuk list horizontal; biarkan null agar mengikuti lebar grid.
/// Bila [onTap] tidak diisi, kartu otomatis membuka [ProductDetailPage].
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.width, this.onTap});

  final Product product;
  final double? width;
  final VoidCallback? onTap;

  /// Tinggi total sel kartu (foto + area teks). Grid Menu & list horizontal
  /// Beranda memakai nilai ini agar selalu sinkron. Fotonya memakai [Expanded]
  /// sehingga otomatis mengisi sisa ruang — proporsi tetap bagus (foto dominan,
  /// tanpa ruang kosong) meski nilai ini diubah. Cukup ubah di SATU tempat ini.
  static const double cellExtent = 186;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ??
          () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailPage(product: product),
                ),
              ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: AppColors.creamSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto mengisi sisa ruang kartu (dominan, tanpa ruang kosong).
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: ProductImage(imageUrl: product.imageUrl),
                  ),
                  if (product.badge != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _Badge(
                        text: product.badge!,
                        background: AppColors.yellow500,
                        foreground: AppColors.maroon900,
                      ),
                    )
                  else if (product.isNew)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: _Badge(
                        text: 'Baru',
                        background: AppColors.maroon700,
                        foreground: AppColors.white,
                      ),
                    ),
                  if (!product.available)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: _Badge(
                        text: 'Habis',
                        background: AppColors.error,
                        foreground: AppColors.white,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tinggi tetap 2 baris agar semua kartu seragam & harga
                  // sejajar (nama 1 baris tetap memesan ruang baris kedua).
                  SizedBox(
                    height: 32,
                    width: double.infinity,
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.15,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (product.isPromo)
                    // FittedBox: skala mengecil hanya bila kombinasi harga
                    // efektif + harga coret tidak muat, tanpa pernah overflow.
                    SizedBox(
                      height: 18,
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatRupiah(product.effectivePrice),
                              style: const TextStyle(
                                color: AppColors.maroon700,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatRupiah(product.price),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.grey400,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Text(
                      formatRupiah(product.price),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.maroon700,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gambar produk dari jaringan, dengan spinner saat memuat dan placeholder
/// ikon (tanpa emoji) bila [imageUrl] null atau gagal dimuat.
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) return _placeholder();
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _placeholder(loading: true);
      },
      errorBuilder: (context, error, stack) => _placeholder(),
    );
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      color: AppColors.yellow50,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(
              Icons.bakery_dining,
              size: 34,
              color: AppColors.grey300,
            ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
