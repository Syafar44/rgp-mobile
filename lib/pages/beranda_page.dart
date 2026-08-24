import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/dummy/dummy_data.dart';
import '../data/models/product.dart';
import '../data/models/promo_banner.dart';
import '../data/notifiers.dart';
import '../widgets/dashed_border.dart';
import '../widgets/product_card.dart';
import 'outlet_page.dart';

/// Halaman Beranda — meniru tata letak aplikasi Kopi Kenangan.
class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key});

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  int _outletIndex = 0;

  Future<void> _pickOutlet() async {
    final selected = await Navigator.push<Outlet>(
      context,
      MaterialPageRoute(builder: (_) => const OutletPage()),
    );
    if (selected == null) return;
    final idx = DummyData.outlets.indexWhere((o) => o.name == selected.name);
    if (idx >= 0) setState(() => _outletIndex = idx);
  }

  /// Tarik-untuk-refresh: muat ulang data (dummy → jeda singkat lalu rebuild).
  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final outlet = DummyData.outlets[_outletIndex];

    return RefreshIndicator(
      onRefresh: _refresh,
      edgeOffset: topPadding,
      color: AppColors.maroon700,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _HeaderDelegate(
              topPadding: topPadding,
              outlet: outlet,
              onTapLocation: _pickOutlet,
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 8),
                const _PromoCarousel(),
                const SizedBox(height: 20),
                const _QuickActions(),
                const SizedBox(height: 20),
                _OrderLagi(),
                const SizedBox(height: 20),
                const _VoucherBanner(),
                const SizedBox(height: 8),
                _ProductSection(
                  title: 'Spesial Hari Ini',
                  products: DummyData.spesialHariIni,
                ),
                _ProductSection(title: 'Baru!', products: DummyData.produkBaru),
                _MakananGrid(products: DummyData.makanan),
                const SizedBox(height: 20),
                const _ContactCard(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// HEADER: pinned. Kartu lokasi selalu bergaya sama.
// - Belum discroll: pill loyalty + kartu (nama+alamat) + "Melayani +
//   Delivery/Pickup" di bawah kartu.
// - Discroll: pill loyalty, alamat, & baris "Melayani" hilang; Delivery/Pickup
//   berpindah masuk ke dalam kartu (tepat di bawah nama outlet).
// =============================================================================

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({
    required this.topPadding,
    required this.outlet,
    required this.onTapLocation,
  });

  final double topPadding;
  final ({String name, String address}) outlet;
  final VoidCallback onTapLocation;

  static const double _collapsedExtra = 92;
  static const double _expandedExtra = 150;

  @override
  double get minExtent => topPadding + _collapsedExtra;

  @override
  double get maxExtent => topPadding + _expandedExtra;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtent - minExtent;
    final t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final visibility = 1 - t; // 1 = tampil penuh, 0 = hilang total.

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.yellow100, AppColors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Pill loyalty — hilang total saat discroll.
          _Collapsible(
            visibility: visibility,
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                _LoyaltyPill(
                  icon: Icons.favorite,
                  iconColor: AppColors.maroon700,
                  text: '${DummyData.loyaltyTier} ${DummyData.loyaltyPercent}%',
                ),
                const SizedBox(width: 14),
                _LoyaltyPill(
                  icon: Icons.stars_rounded,
                  iconColor: AppColors.gold500,
                  text: '${DummyData.poin} pts',
                ),
                const Spacer(),
                // TODO: ganti dengan ilustrasi awan (di-skip dulu).
              ],
            ),
          ),
          // Kartu lokasi — gaya selalu sama. Saat discroll, alamat hilang dan
          // Delivery/Pickup "pindah" masuk ke dalam kartu (di bawah nama).
          _LocationCard(
            outlet: outlet,
            onTap: onTapLocation,
            expandedVisibility: visibility,
          ),
          // "Melayani + Delivery/Pickup" di bawah kartu — hilang saat discroll.
          _Collapsible(
            visibility: visibility,
            padding: const EdgeInsets.only(top: 12),
            child: const _ServiceInfo(showLabel: true),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) =>
      oldDelegate.outlet != outlet || oldDelegate.topPadding != topPadding;
}

/// Membungkus [child] agar tinggi & opasitasnya menciut ke nol mengikuti
/// [visibility] (1 = tampil penuh, 0 = hilang total tanpa sisa ruang).
class _Collapsible extends StatelessWidget {
  const _Collapsible({
    required this.visibility,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final double visibility;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final v = visibility.clamp(0.0, 1.0);
    return ClipRect(
      child: Align(
        heightFactor: v,
        alignment: Alignment.topCenter,
        child: Opacity(
          opacity: v,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Pill loyalty tanpa kotak/latar — hanya ikon + teks.
class _LoyaltyPill extends StatelessWidget {
  const _LoyaltyPill({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.outlet,
    required this.onTap,
    this.expandedVisibility = 1,
  });

  final ({String name, String address}) outlet;
  final VoidCallback onTap;

  /// Progres header: 1 = belum discroll (alamat tampil, Delivery/Pickup di
  /// dalam kartu tersembunyi), 0 = discroll penuh (alamat hilang,
  /// Delivery/Pickup tampil di dalam kartu).
  final double expandedVisibility;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          outlet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  // Alamat — tampil saat belum discroll.
                  _Collapsible(
                    visibility: expandedVisibility,
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      outlet.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grey600,
                      ),
                    ),
                  ),
                  // Delivery/Pickup — "pindah" masuk ke kartu saat discroll.
                  _Collapsible(
                    visibility: 1 - expandedVisibility,
                    padding: const EdgeInsets.only(top: 4),
                    child: const _ServiceInfo(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.keyboard_arrow_down_outlined,
                color: scheme.primary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Info layanan outlet (Delivery/Pickup) — murni informasi, tanpa aksi.
///
/// [showLabel] true untuk versi di bawah kartu (diawali "Melayani"), false
/// untuk versi ringkas di dalam kartu saat discroll.
class _ServiceInfo extends StatelessWidget {
  const _ServiceInfo({this.showLabel = false});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showLabel) ...[
          const Text(
            'Melayani',
            style: TextStyle(fontSize: 13, color: AppColors.grey600),
          ),
          const SizedBox(width: 16),
        ],
        const _ServiceDot(color: AppColors.success, label: 'Delivery'),
        const SizedBox(width: 16),
        const _ServiceDot(color: AppColors.info, label: 'Pickup'),
      ],
    );
  }
}

class _ServiceDot extends StatelessWidget {
  const _ServiceDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle_outlined, size: 12, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textDark),
        ),
      ],
    );
  }
}

// =============================================================================
// CAROUSEL PROMO
// =============================================================================

class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel();

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = DummyData.banners;
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _BannerCard(banner: banners[i]),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _page == i ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _page == i ? AppColors.maroon700 : AppColors.grey300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner});

  final PromoBanner banner;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.maroon900,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Foto latar (dummy dari sumber gambar gratis).
          Image.network(
            banner.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const SizedBox.shrink(),
          ),
          // Overlay gelap agar teks tetap terbaca di atas foto.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.maroon900.withValues(alpha: 0.92),
                  AppColors.maroon900.withValues(alpha: 0.55),
                  AppColors.maroon900.withValues(alpha: 0.05),
                ],
                stops: const [0, 0.55, 1],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          // Logo kecil pojok kanan atas.
          const Positioned(
            top: 10,
            right: 12,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.white,
              child: Text('🍞', style: TextStyle(fontSize: 14)),
            ),
          ),
          // Konten teks.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 100, 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner.label,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  banner.title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  banner.highlight,
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppColors.gold500,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  banner.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.85),
                    fontSize: 10,
                  ),
                ),
                if (banner.badges.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final b in banner.badges) _BannerBadge(text: b),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerBadge extends StatelessWidget {
  const _BannerBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.yellow500,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.maroon900,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// =============================================================================
// QUICK ACTIONS
// =============================================================================

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _ActionCard(
              icon: Icons.receipt_long,
              title: 'Order',
              subtitle: 'Pesan sekarang',
              onTap: () => selectedPageNotifier.value = 2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionCard(
              icon: Icons.delivery_dining,
              title: 'Delivery',
              badge: 'Disc 40%',
              onTap: () => selectedPageNotifier.value = 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu aksi cepat: chip ikon solid (kontras kuat) + judul + subtitle/badge.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.creamSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.grey100),
          ),
          child: Row(
            children: [
              // Chip ikon solid maroon + ikon putih = kontras tinggi.
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.maroon700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellow500,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.maroon900,
                          ),
                        ),
                      )
                    else if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.grey600,
                        ),
                      ),
                  ],
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
// ORDER LAGI
// =============================================================================

class _OrderLagi extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = DummyData.orderLagi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Order Lagi'),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _OrderLagiCard(item: items[i]),
          ),
        ),
      ],
    );
  }
}

class _OrderLagiCard extends StatelessWidget {
  const _OrderLagiCard({required this.item});

  final ({Product product, String outletLabel}) item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final product = item.product;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.creamSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 48,
              height: 48,
              child: ProductImage(imageUrl: product.imageUrl),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.outletLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.maroon700,
                  ),
                ),
                Text(
                  '1x ${product.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _snack(context, product.name),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(56, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: BorderSide(color: scheme.primary),
            ),
            child: const Text('Beli', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// VOUCHER BANNER
// =============================================================================

class _VoucherBanner extends StatelessWidget {
  const _VoucherBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DashedRoundedBorder(
        color: AppColors.maroon700,
        radius: 16,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.yellow100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('💌', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Voucher Beli 1 Gratis 1 SEPUASNYA!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.maroon900,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => _snack(context, 'Voucher diklaim'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('Klaim'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION PRODUK (horizontal)
// =============================================================================

class _ProductSection extends StatelessWidget {
  const _ProductSection({required this.title, required this.products});

  final String title;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, onSeeAll: () {}),
        SizedBox(
          height: ProductCard.cellExtent,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                ProductCard(product: products[i], width: 150),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// =============================================================================
// GRID MAKANAN (2 kolom)
// =============================================================================

class _MakananGrid extends StatelessWidget {
  const _MakananGrid({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Makanan', onSeeAll: () {}),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: ProductCard.cellExtent,
            ),
            itemBuilder: (context, i) => ProductCard(product: products[i]),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// KARTU KONTAK (WhatsApp) + info
// =============================================================================

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Butuh Bantuan?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.creamSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.grey100),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat, color: AppColors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Curhat ke 0812 3456 7890 (Chat Only)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Informasi Kontak Layanan Pengaduan Konsumen Direktorat Jenderal '
            'Perlindungan Konsumen dan Tertib Niaga, Kementerian Perdagangan '
            'Republik Indonesia.\nWhatsApp Ditjen PKTN: 0853-1111-1010',
            style: TextStyle(fontSize: 11, color: AppColors.grey600),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION HEADER (judul + "lihat semua")
// =============================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (onSeeAll != null)
            IconButton(
              onPressed: onSeeAll,
              icon: const Icon(Icons.chevron_right),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
  );
}
