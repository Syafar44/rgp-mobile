import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/app_features.dart';
import '../core/config/app_images.dart';
import '../core/config/app_links.dart';
import '../core/theme/app_colors.dart';
import '../data/cart_store.dart';
import '../data/dummy/dummy_data.dart';
import '../data/menu_repository.dart';
import '../data/models/product.dart';
import '../data/models/promo_banner.dart';
import '../data/notifiers.dart';
import '../data/order_store.dart';
import '../data/outlet_store.dart';
import '../widgets/product_card.dart';
import 'outlet_page.dart';
import '../widgets/outlet_switch.dart';

/// Halaman Beranda — meniru tata letak aplikasi Kopi Kenangan.
class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key});

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  /// Preview menu "Roti Gembung" di Beranda. Belum ada endpoint rekomendasi,
  /// jadi pakai endpoint menu outlet lalu saring hanya Roti Gembung, ambil 6
  /// produk terbawah.
  List<Product> _rotiGembung = const [];
  int? _menuOutletId;

  @override
  void initState() {
    super.initState();
    outletStore.selected.addListener(_onOutletChanged);
    selectedPageNotifier.addListener(_onTabChanged);
    _loadMenu();
    orderStore.refresh();
  }

  @override
  void dispose() {
    outletStore.selected.removeListener(_onOutletChanged);
    selectedPageNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onOutletChanged() {
    if (outletStore.outletId != _menuOutletId) _loadMenu();
  }

  /// Tiap kembali ke Beranda, tanyakan lagi keadaan pesanan ke server.
  ///
  /// Beranda dipilih sebagai titik periksa karena ke sinilah pembeli pulang
  /// setelah selesai di layar lain. Tanpa ini, bilah "pesanan sedang diproses"
  /// bisa bertahan di layar setelah pesanannya sebenarnya sudah diserahkan
  /// kasir atau kedaluwarsa — dan selama bilah itu ada, bilah keranjang
  /// tersembunyi dan pesanan baru tertahan.
  ///
  /// Halaman ini hidup terus di dalam `IndexedStack`, jadi `initState` saja
  /// tidak cukup: pemeriksaannya harus ikut perpindahan tab.
  void _onTabChanged() {
    if (selectedPageNotifier.value != 0) return;
    orderStore.refresh();
    // Keranjang ikut ditanyakan ulang: server yang mengosongkannya setelah
    // pembayaran masuk, jadi tanpa memuat ulang, bilah keranjang bisa muncul
    // lagi berisi barang yang sebenarnya sudah menjadi pesanan.
    cartStore.syncWithSelectedOutlet();
  }

  Future<void> _loadMenu() async {
    final id = outletStore.outletId;
    _menuOutletId = id;
    if (id == null) {
      if (mounted) setState(() => _rotiGembung = const []);
      return;
    }
    try {
      final products = await menuRepository.outletMenus(id);
      if (!mounted) return;
      final roti = products
          .where(
            (p) => p.category.trim().toLowerCase().contains('roti gembung'),
          )
          .toList();
      // Ambil 6 produk terbawah (paling akhir pada daftar).
      final preview = roti.length > 6 ? roti.sublist(roti.length - 6) : roti;
      setState(() => _rotiGembung = preview);
    } catch (_) {
      if (!mounted) return;
      setState(() => _rotiGembung = const []); // sembunyikan bila gagal
    }
  }

  Future<void> _pickOutlet() async {
    final selected = await Navigator.push<Outlet>(
      context,
      MaterialPageRoute(builder: (_) => const OutletPage()),
    );
    if (selected != null && mounted) await switchOutlet(context, selected);
  }

  /// Tarik-untuk-refresh: muat ulang preview menu.
  Future<void> _refresh() => _loadMenu();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return ValueListenableBuilder<Outlet?>(
      valueListenable: outletStore.selected,
      builder: (context, outlet, _) => RefreshIndicator(
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
                  _MenuGrid(
                    title: 'Roti Gembung',
                    products: _rotiGembung,
                    onSeeAll: () => selectedPageNotifier.value = 1,
                  ),
                  const SizedBox(height: 10),
                  const _ContactCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
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
  final Outlet? outlet;
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
                // Selama endpoint loyalty belum ada: satu pill penanda, bukan
                // dua pill berisi angka karangan. Dua-duanya berbunyi "Segera
                // hadir" hanya akan terbaca seperti kerusakan.
                if (AppFeatures.loyalty) ...[
                  _LoyaltyPill(
                    icon: Icons.favorite,
                    iconColor: AppColors.maroon700,
                    text:
                        '${DummyData.loyaltyTier} ${DummyData.loyaltyPercent}%',
                  ),
                  const SizedBox(width: 14),
                  _LoyaltyPill(
                    icon: Icons.stars_rounded,
                    iconColor: AppColors.gold500,
                    text: '${DummyData.poin} pts',
                  ),
                ] else
                  _LoyaltyPill(
                    icon: Icons.stars_rounded,
                    iconColor: AppColors.grey400,
                    text: 'Panglima Points · ${AppFeatures.segeraHadir}',
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

  final Outlet? outlet;
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
                          outlet?.name ?? 'Pilih Outlet Panglima',
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
                      outlet?.address ?? 'Ketuk untuk pilih outlet terdekat',
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
    // Tinggi mengikuti rasio banner supaya gambarnya tampil utuh. Dengan
    // tinggi tetap, sisi kiri-kanan akan terpotong dan teks di tepi desain
    // (nomor telepon, ikon media sosial) ikut hilang.
    const viewport = 0.9; // sama dengan viewportFraction PageView
    const margin = 12.0; // margin kiri+kanan kartu
    final cardWidth = MediaQuery.of(context).size.width * viewport - margin;
    final height = cardWidth / AppImages.bannerAspect;

    return Column(
      children: [
        SizedBox(
          height: height,
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

/// Satu banner promo — gambar jadi, ditampilkan utuh.
///
/// Tidak ada overlay gradien maupun teks dari aplikasi: judul, penawaran, dan
/// kontak sudah menjadi bagian desain banner, jadi menimpakan teks lagi hanya
/// akan bertabrakan.
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
      child: Semantics(
        label: banner.label.isEmpty ? 'Banner promo' : banner.label,
        image: true,
        child: banner.isNetwork
            ? Image.network(
                banner.image,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const SizedBox.shrink(),
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              )
            : Image.asset(
                banner.image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
      ),
    );
  }
}

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
              onTap: () => selectedPageNotifier.value = menuTabIndex,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionCard(
              icon: Icons.delivery_dining,
              title: 'Delivery',
              // Badge diskon dilepas selama fiturnya terkunci: menjanjikan
              // potongan untuk layanan yang belum bisa dipakai.
              subtitle: AppFeatures.segeraHadir,
              locked: !AppFeatures.delivery,
              onTap: () => selectedPageNotifier.value = menuTabIndex,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu aksi cepat: chip ikon solid (kontras kuat) + judul + subtitle.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.locked = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;

  /// Fitur belum rilis: kartu tetap terlihat tapi redup, bergembok, dan tidak
  /// bisa ditekan.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.creamSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: locked ? null : onTap,
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
                  color: locked ? AppColors.grey300 : AppColors.maroon700,
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: locked
                                  ? AppColors.grey400
                                  : AppColors.textDark,
                            ),
                          ),
                        ),
                        if (locked) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.lock_outline,
                            size: 13,
                            color: AppColors.grey400,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: locked
                              ? AppColors.grey400
                              : AppColors.grey600,
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
// GRID MENU (2 kolom) — preview di Beranda
// =============================================================================

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.title, required this.products, this.onSeeAll});

  final String title;
  final List<Product> products;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, onSeeAll: onSeeAll),
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

  /// Buka chat WhatsApp layanan pelanggan.
  Future<void> _bukaWhatsApp(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var terbuka = false;
    try {
      terbuka = await launchUrl(
        AppLinks.whatsappChat,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Ditangani di bawah — sama seperti gagal dibuka.
    }
    if (!terbuka) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'WhatsApp tidak bisa dibuka. Hubungi 08 222 000 2237 lewat chat.',
          ),
        ),
      );
    }
  }

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
          Material(
            color: AppColors.creamSurface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => _bukaWhatsApp(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
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
                        'Curhat ke 08 222 000 2237 (Chat Only)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.grey400,
                    ),
                  ],
                ),
              ),
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
