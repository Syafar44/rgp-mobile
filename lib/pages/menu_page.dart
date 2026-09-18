import 'package:flutter/material.dart';

import '../core/network/api_error.dart';
import '../core/theme/app_colors.dart';
import '../data/menu_repository.dart';
import '../data/models/product.dart';
import '../data/outlet_store.dart';
import '../widgets/product_card.dart';
import 'outlet_page.dart';

/// Data satu section kategori pada halaman Menu.
typedef MenuSection = ({String title, List<Product> items});

/// Halaman Menu — meniru tata letak menu Kopi Kenangan:
/// pilih outlet, tab kategori yang tersinkron dengan scroll, lalu daftar
/// produk 2 kolom yang dipisah per kategori.
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final ScrollController _scroll = ScrollController();
  final ScrollController _tabScroll = ScrollController();
  final GlobalKey _listKey = GlobalKey();

  List<MenuSection> _sections = const [];
  List<GlobalKey> _sectionKeys = const [];
  List<GlobalKey> _tabKeys = const [];

  int _activeTab = 0;
  bool _loading = false;
  String? _error;

  /// id outlet yang menunya sedang dimuat — cegah fetch ganda saat outlet sama.
  int? _loadedOutletId;

  /// True saat scroll dipicu penekanan tab (agar scroll-spy tidak bentrok).
  bool _programmaticScroll = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    outletStore.selected.addListener(_onOutletChanged);
    _load();
  }

  @override
  void dispose() {
    outletStore.selected.removeListener(_onOutletChanged);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _tabScroll.dispose();
    super.dispose();
  }

  void _onOutletChanged() {
    if (outletStore.outletId != _loadedOutletId) _load();
  }

  /// Ambil menu untuk outlet yang sedang dipilih (`/outlets/:id/menus`).
  Future<void> _load() async {
    final id = outletStore.outletId;
    if (id == null) {
      setState(() {
        _sections = const [];
        _sectionKeys = const [];
        _tabKeys = const [];
        _loading = false;
        _error = null;
        _loadedOutletId = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await menuRepository.outletMenus(id);
      if (!mounted) return;
      final sections = _group(products);
      setState(() {
        _sections = sections;
        _sectionKeys = List.generate(sections.length, (_) => GlobalKey());
        _tabKeys = List.generate(sections.length, (_) => GlobalKey());
        _activeTab = 0;
        _loading = false;
        _loadedOutletId = id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
        _loadedOutletId = id;
      });
    }
  }

  /// Hanya kategori ini yang ditampilkan (urutannya juga urutan tampil).
  static const List<String> _allowedCategories = [
    'Roti Gembung',
    'Bakpia',
    'Donat',
    'Pizza',
  ];

  /// Tentukan kategori sebuah produk di antara [_allowedCategories].
  ///
  /// Respons dikelompokkan per kategori (`{category, data: [...]}`), jadi
  /// [Product.category] berisi nama kategori dari server. Dicocokkan dengan
  /// `contains` agar tahan variasi ejaan (mis. "Roti Gembung Panglima" →
  /// Roti Gembung). Null bila di luar daftar.
  String? _matchCategory(Product p) {
    final cat = p.category.trim().toLowerCase();
    for (final c in _allowedCategories) {
      if (cat.contains(c.toLowerCase())) return c;
    }
    if (cat.contains('donut')) return 'Donat'; // variasi ejaan umum
    return null;
  }

  /// Kelompokkan produk per kategori — hanya [_allowedCategories], urut sesuai
  /// daftar itu; kategori lain dibuang.
  List<MenuSection> _group(List<Product> products) {
    final byCat = <String, List<Product>>{};
    for (final p in products) {
      final cat = _matchCategory(p);
      if (cat == null) continue; // di luar daftar → tidak ditampilkan
      (byCat[cat] ??= <Product>[]).add(p);
    }
    return [
      for (final c in _allowedCategories)
        if (byCat[c]?.isNotEmpty ?? false) (title: c, items: byCat[c]!),
    ];
  }

  /// Sinkronkan tab aktif dengan posisi scroll.
  void _onScroll() {
    if (_programmaticScroll) return;
    final listCtx = _listKey.currentContext;
    if (listCtx == null) return;
    final listTop = (listCtx.findRenderObject() as RenderBox)
        .localToGlobal(Offset.zero)
        .dy;
    final threshold = listTop + 24;

    int active = 0;
    for (int i = 0; i < _sectionKeys.length; i++) {
      final ctx = _sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final top = (ctx.findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero)
          .dy;
      if (top <= threshold) active = i;
    }
    if (active != _activeTab) {
      setState(() => _activeTab = active);
      _ensureTabVisible(active);
    }
  }

  /// Scroll list ke section [i] saat tab ditekan.
  Future<void> _onTabTap(int i) async {
    setState(() => _activeTab = i);
    _ensureTabVisible(i);
    final ctx = _sectionKeys[i].currentContext;
    if (ctx == null) return;
    _programmaticScroll = true;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _programmaticScroll = false;
  }

  /// Tarik-untuk-refresh: muat ulang menu dari API.
  Future<void> _refresh() => _load();

  /// Geser tab bar horizontal agar tab aktif terlihat.
  void _ensureTabVisible(int i) {
    final ctx = _tabKeys[i].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      alignment: 0.5,
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<Outlet?>(
            valueListenable: outletStore.selected,
            builder: (context, outlet, _) =>
                _OutletSelector(outlet: outlet, onTap: _pickOutlet),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.maroon700),
      );
    }
    if (_error != null) {
      return _MenuStatus(
        icon: Icons.error_outline,
        message: _error!,
        onRetry: _load,
      );
    }
    if (outletStore.outletId == null) {
      return const _MenuStatus(
        icon: Icons.storefront_outlined,
        message: 'Pilih outlet Panglima dulu untuk melihat menu.',
      );
    }
    if (_sections.isEmpty) {
      return _MenuStatus(
        icon: Icons.restaurant_menu,
        message: 'Menu belum tersedia untuk outlet ini.',
        onRetry: _load,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryTabs(
          sections: _sections,
          tabKeys: _tabKeys,
          activeIndex: _activeTab,
          controller: _tabScroll,
          onTap: _onTabTap,
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.maroon700,
            child: ListView(
              key: _listKey,
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              // Bangun semua section agar tab bisa langsung loncat & sinkron.
              cacheExtent: 3000,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (int i = 0; i < _sections.length; i++)
                  _CategorySection(
                    key: _sectionKeys[i],
                    section: _sections[i],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickOutlet() async {
    final selected = await Navigator.push<Outlet>(
      context,
      MaterialPageRoute(builder: (_) => const OutletPage()),
    );
    if (selected != null) outletStore.select(selected);
  }
}

// =============================================================================
// PILIH OUTLET
// =============================================================================

class _OutletSelector extends StatelessWidget {
  const _OutletSelector({required this.outlet, required this.onTap});

  final Outlet? outlet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: InkWell(
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
                    Text(
                      outlet?.name ?? 'Pilih Outlet Panglima',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      outlet?.address ?? 'Ketuk untuk pilih outlet terdekat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grey600,
                      ),
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
      ),
    );
  }
}

// =============================================================================
// TAB KATEGORI
// =============================================================================

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.sections,
    required this.tabKeys,
    required this.activeIndex,
    required this.controller,
    required this.onTap,
  });

  final List<MenuSection> sections;
  final List<GlobalKey> tabKeys;
  final int activeIndex;
  final ScrollController controller;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (int i = 0; i < sections.length; i++)
              InkWell(
                key: tabKeys[i],
                onTap: () => onTap(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          sections[i].title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: i == activeIndex
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: i == activeIndex
                                ? scheme.primary
                                : AppColors.grey600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: i == activeIndex
                                ? scheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
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
// SECTION KATEGORI (grid 2 kolom)
// =============================================================================

class _CategorySection extends StatelessWidget {
  const _CategorySection({super.key, required this.section});

  final MenuSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            section.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: section.items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: ProductCard.cellExtent,
            ),
            itemBuilder: (context, i) => ProductCard(product: section.items[i]),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// STATUS (memuat gagal / kosong)
// =============================================================================

class _MenuStatus extends StatelessWidget {
  const _MenuStatus({required this.icon, required this.message, this.onRetry});

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.grey300),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey600),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
