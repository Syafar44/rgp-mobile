import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatter.dart';
import '../data/dummy/dummy_data.dart';
import '../data/models/vip.dart';

/// Halaman VIP ("Panglima VIP") — meniru halaman keanggotaan Kopi Kenangan:
/// carousel kartu tier (Silver/Gold/Black) di atas, lalu lembar putih berisi
/// tab Voucher / Voucher Pack / Benefit yang berganti isi mengikuti tier aktif.
class VipPage extends StatefulWidget {
  const VipPage({super.key});

  @override
  State<VipPage> createState() => _VipPageState();
}

class _VipPageState extends State<VipPage> {
  late final PageController _pageController;
  late int _activeTier;
  int _activeTab = 0; // 0=Voucher, 1=Voucher Pack, 2=Benefit
  String _voucherFilter = 'Semua';

  final List<VipTier> _tiers = DummyData.vipTiers;

  static const List<String> _tabs = ['Voucher', 'Voucher Pack', 'Benefit'];

  @override
  void initState() {
    super.initState();
    _activeTier = DummyData.vipCurrentTierIndex;
    _pageController = PageController(
      initialPage: _activeTier,
      viewportFraction: 0.88,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Tarik-untuk-refresh: muat ulang data (dummy → jeda singkat lalu rebuild).
  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tier = _tiers[_activeTier];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: tier.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _VipTopBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.maroon700,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 214,
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _tiers.length,
                              onPageChanged: (i) =>
                                  setState(() => _activeTier = i),
                              itemBuilder: (context, i) =>
                                  _TierCard(tier: _tiers[i]),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _PageDots(count: _tiers.length, active: _activeTier),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarDelegate(
                        tabs: _tabs,
                        activeIndex: _activeTab,
                        onTap: (i) => setState(() => _activeTab = i),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        color: AppColors.white,
                        constraints: const BoxConstraints(minHeight: 320),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        child: _TabContent(
                          tier: tier,
                          tab: _activeTab,
                          voucherFilter: _voucherFilter,
                          onFilterChanged: (f) =>
                              setState(() => _voucherFilter = f),
                        ),
                      ),
                    ),
                  ],
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
// TOP BAR
// =============================================================================

class _VipTopBar extends StatelessWidget {
  const _VipTopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          const SizedBox(width: 40),
          const Expanded(
            child: Text(
              'Panglima VIP',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () => _snack(context, 'Info program Panglima VIP'),
            icon: const Icon(Icons.help_outline),
            color: AppColors.grey600,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// KARTU TIER (carousel)
// =============================================================================

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier});

  final VipTier tier;

  @override
  Widget build(BuildContext context) {
    final onCard = tier.onCard;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: tier.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tier.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: onCard,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TierBadge(tier: tier),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hai, ${DummyData.vipMemberName}',
                      style: TextStyle(
                        fontSize: 13,
                        color: onCard.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: formatPoin(tier.points),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: onCard,
                            ),
                          ),
                          TextSpan(
                            text: ' / ${formatPoin(tier.goal)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: onCard.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: tier.progress,
                        minHeight: 6,
                        backgroundColor: onCard.withValues(alpha: 0.18),
                        valueColor: AlwaysStoppedAnimation(tier.barColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tier.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        color: onCard.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _TierEmblem(tier: tier),
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});

  final VipTier tier;

  @override
  Widget build(BuildContext context) {
    final onCard = tier.onCard;
    // Tier saat ini: chip solid mencolok. Lainnya: chip transparan tipis.
    final isCurrent = tier.status == TierStatus.current;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCurrent ? onCard : onCard.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: onCard.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tier.isLocked) ...[
            Icon(Icons.lock, size: 11, color: onCard),
            const SizedBox(width: 3),
          ],
          Text(
            tier.badge,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isCurrent ? tier.gradient.last : onCard,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierEmblem extends StatelessWidget {
  const _TierEmblem({required this.tier});

  final VipTier tier;

  @override
  Widget build(BuildContext context) {
    final onCard = tier.onCard;
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            onCard.withValues(alpha: 0.22),
            onCard.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: onCard.withValues(alpha: 0.35), width: 2),
      ),
      child: Icon(tier.emblem, size: 34, color: onCard),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 20 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == active ? AppColors.maroon700 : AppColors.grey300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// TAB BAR (pinned) — segmented control
// =============================================================================

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({
    required this.tabs,
    required this.activeIndex,
    required this.onTap,
  });

  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onTap;

  static const double _height = 68;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            for (int i = 0; i < tabs.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == activeIndex
                          ? AppColors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: i == activeIndex
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      tabs[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: i == activeIndex
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: i == activeIndex
                            ? AppColors.maroon700
                            : AppColors.grey600,
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

  @override
  bool shouldRebuild(covariant _TabBarDelegate old) =>
      old.activeIndex != activeIndex || old.tabs != tabs;
}

// =============================================================================
// ISI TAB
// =============================================================================

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.tier,
    required this.tab,
    required this.voucherFilter,
    required this.onFilterChanged,
  });

  final VipTier tier;
  final int tab;
  final String voucherFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case 1:
        return _PackTab(tier: tier);
      case 2:
        return _BenefitTab(tier: tier);
      default:
        return _VoucherTab(
          tier: tier,
          filter: voucherFilter,
          onFilterChanged: onFilterChanged,
        );
    }
  }
}

// --- Tab Voucher -------------------------------------------------------------

class _VoucherTab extends StatelessWidget {
  const _VoucherTab({
    required this.tier,
    required this.filter,
    required this.onFilterChanged,
  });

  final VipTier tier;
  final String filter;
  final ValueChanged<String> onFilterChanged;

  static const List<String> _filters = [
    'Semua',
    'Diskon',
    'Cashback',
    'Delivery',
  ];

  @override
  Widget build(BuildContext context) {
    final vouchers = filter == 'Semua'
        ? tier.vouchers
        : tier.vouchers.where((v) => v.category == filter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _VoucherCodeField(),
        const SizedBox(height: 20),
        const _SectionLabel('Diskon & Cashback'),
        const SizedBox(height: 12),
        const _ClaimRow(),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in _filters) ...[
                _FilterChip(
                  label: f,
                  selected: f == filter,
                  onTap: () => onFilterChanged(f),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SectionLabel('Voucher Tersedia'),
        const SizedBox(height: 12),
        if (vouchers.isEmpty)
          _EmptyHint(
            icon: Icons.confirmation_number_outlined,
            text: 'Belum ada voucher $filter untuk tier ini.',
          )
        else
          for (final v in vouchers) ...[
            _VoucherCard(voucher: v, locked: tier.isLocked),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _VoucherCodeField extends StatelessWidget {
  const _VoucherCodeField();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey300),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            color: AppColors.maroon700,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Masukkan kode voucher',
              style: TextStyle(color: AppColors.grey400, fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () => _snack(context, 'Kode voucher dipakai (dummy)'),
            child: const Text(
              'Pakai',
              style: TextStyle(
                color: AppColors.maroon700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimRow extends StatelessWidget {
  const _ClaimRow();

  static const List<({String tag, String value, String unit})> _claims = [
    (tag: 'Ongkir', value: 'Gratis', unit: 'GoSend'),
    (tag: 'Ongkir', value: '5.000', unit: 'GExpress'),
    (tag: 'Diskon', value: '10%', unit: 'Semua Menu'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _claims.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _ClaimCard(claim: _claims[i]),
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim});

  final ({String tag, String value, String unit}) claim;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.creamSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    claim.tag,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  claim.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  claim.unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.grey600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MaroonOutlineButton(
            label: 'Klaim',
            onTap: () =>
                _snack(context, 'Voucher ${claim.tag} diklaim (dummy)'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.maroon50 : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.maroon700 : AppColors.grey300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? AppColors.maroon700 : AppColors.grey600,
          ),
        ),
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.voucher, required this.locked});

  final VipVoucher voucher;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColor(voucher.category);
    return Opacity(
      opacity: locked ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  voucher.tag,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    voucher.category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: catColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _categoryIcon(voucher.category),
                    color: catColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucher.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        voucher.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.grey600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _DottedLine(),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: AppColors.grey400),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Berlaku hingga ${voucher.validUntil}',
                    style: TextStyle(fontSize: 11, color: AppColors.grey600),
                  ),
                ),
                if (locked)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock,
                        size: 14,
                        color: AppColors.grey400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Terkunci',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.grey400,
                        ),
                      ),
                    ],
                  )
                else
                  _MaroonFilledButton(
                    label: 'Pakai Voucher',
                    onTap: () =>
                        _snack(context, '${voucher.title} dipakai (dummy)'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Tab Voucher Pack --------------------------------------------------------

class _PackTab extends StatelessWidget {
  const _PackTab({required this.tier});

  final VipTier tier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Tersedia'),
        const SizedBox(height: 12),
        for (final p in tier.packs) ...[
          _VoucherPackCard(pack: p, locked: tier.isLocked),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _VoucherPackCard extends StatelessWidget {
  const _VoucherPackCard({required this.pack, required this.locked});

  final VipVoucherPack pack;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey100),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pack.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.grey600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _VoucherCountChip(count: pack.voucherCount),
            ],
          ),
          const SizedBox(height: 12),
          const _DottedLine(),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatRupiah(pack.originalPrice),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.grey400,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Hemat ${pack.savePercent}%',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatRupiah(pack.price),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.maroon700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              locked
                  ? _LockedButton()
                  : _MaroonFilledButton(
                      label: 'Beli Paket',
                      onTap: () =>
                          _snack(context, '${pack.title} dibeli (dummy)'),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoucherCountChip extends StatelessWidget {
  const _VoucherCountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.maroon50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            size: 18,
            color: AppColors.maroon700,
          ),
          const SizedBox(height: 2),
          Text(
            '${count}x',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.maroon700,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Tab Benefit -------------------------------------------------------------

class _BenefitTab extends StatelessWidget {
  const _BenefitTab({required this.tier});

  final VipTier tier;

  @override
  Widget build(BuildContext context) {
    final locked = tier.isLocked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (locked)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Naik ke Level ${tier.name} untuk membuka semua keuntungan ini.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (int i = 0; i < tier.benefits.length; i++) ...[
          if (i > 0) const Divider(height: 24, indent: 52),
          _BenefitRow(benefit: tier.benefits[i], locked: locked),
        ],
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit, required this.locked});

  final VipBenefit benefit;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final iconColor = locked ? AppColors.grey400 : AppColors.maroon700;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: locked ? AppColors.grey100 : AppColors.maroon50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            locked ? Icons.lock_outline : benefit.icon,
            size: 20,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                benefit.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                benefit.description,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.grey600,
                  height: 1.3,
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
// POTONGAN KECIL
// =============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }
}

/// Garis putus-putus horizontal (pemisah pada kartu voucher/pack).
class _DottedLine extends StatelessWidget {
  const _DottedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 5.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: dash, height: 1, color: AppColors.grey300),
          ),
        );
      },
    );
  }
}

class _MaroonFilledButton extends StatelessWidget {
  const _MaroonFilledButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.maroon700,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _MaroonOutlineButton extends StatelessWidget {
  const _MaroonOutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.maroon700,
        side: const BorderSide(color: AppColors.maroon700),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        minimumSize: const Size(0, 34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _LockedButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock, size: 14, color: AppColors.grey400),
          const SizedBox(width: 4),
          Text(
            'Terkunci',
            style: TextStyle(
              color: AppColors.grey400,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.grey300),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.grey600),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// HELPER
// =============================================================================

Color _categoryColor(String category) {
  switch (category) {
    case 'Cashback':
      return AppColors.info;
    case 'Delivery':
      return AppColors.success;
    default: // Diskon
      return AppColors.maroon700;
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'Cashback':
      return Icons.savings_outlined;
    case 'Delivery':
      return Icons.delivery_dining;
    default: // Diskon
      return Icons.local_offer_outlined;
  }
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
  );
}
