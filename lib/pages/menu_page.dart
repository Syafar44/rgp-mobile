import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/dummy/dummy_data.dart';
import '../data/models/product.dart';
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

  late final List<MenuSection> _sections = DummyData.menuSections;
  late final List<GlobalKey> _sectionKeys = List.generate(
    _sections.length,
    (_) => GlobalKey(),
  );
  late final List<GlobalKey> _tabKeys = List.generate(
    _sections.length,
    (_) => GlobalKey(),
  );

  int _outletIndex = 0;
  int _activeTab = 0;

  /// True saat scroll dipicu penekanan tab (agar scroll-spy tidak bentrok).
  bool _programmaticScroll = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _tabScroll.dispose();
    super.dispose();
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

  /// Tarik-untuk-refresh: muat ulang data (dummy → jeda singkat lalu rebuild).
  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() {});
  }

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
          _OutletSelector(
            outlet: DummyData.outlets[_outletIndex],
            onTap: _pickOutlet,
          ),
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
      ),
    );
  }

  Future<void> _pickOutlet() async {
    final selected = await Navigator.push<Outlet>(
      context,
      MaterialPageRoute(builder: (_) => const OutletPage()),
    );
    if (selected == null) return;
    final idx = DummyData.outlets.indexWhere((o) => o.name == selected.name);
    if (idx >= 0) setState(() => _outletIndex = idx);
  }
}

// =============================================================================
// PILIH OUTLET
// =============================================================================

class _OutletSelector extends StatelessWidget {
  const _OutletSelector({required this.outlet, required this.onTap});

  final ({String name, String address}) outlet;
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
                      outlet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      outlet.address,
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
