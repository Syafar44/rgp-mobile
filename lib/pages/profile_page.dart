import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/dummy/dummy_data.dart';
import 'address_page.dart';

/// Halaman Profile ("Saya") — meniru tata letak Kopi Kenangan:
/// header sapaan + level/poin, daily check-in, lalu grup menu.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _biometric = true;

  /// Tarik-untuk-refresh: muat ulang data (dummy → jeda singkat lalu rebuild).
  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.maroon700,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const _ProfileHeader(),
          const SizedBox(height: 16),
          const _DailyCheckIn(),
          const SizedBox(height: 20),
          _SectionTitle('Akun'),
          _MenuCard(
            children: [
              _MenuTile(
                icon: Icons.inbox_outlined,
                label: 'Kotak Masuk',
                onTap: () => _snack(context, 'Kotak Masuk'),
              ),
              _MenuTile(
                icon: Icons.location_on_outlined,
                label: 'Alamat Pengiriman',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddressPage()),
                ),
              ),
              _MenuTile(
                icon: Icons.qr_code_scanner,
                label: 'Scan Merchandise',
                onTap: () => _snack(context, 'Scan Merchandise'),
              ),
              _MenuTile(
                icon: Icons.fingerprint,
                label: 'Aktifkan Biometric ID',
                trailing: Switch(
                  value: _biometric,
                  onChanged: (v) => setState(() => _biometric = v),
                ),
              ),
              _MenuTile(
                icon: Icons.language,
                label: 'Ubah Bahasa Aplikasi',
                onTap: () => _snack(context, 'Ubah Bahasa'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle('Pesan'),
          _MenuCard(
            children: [
              _MenuTile(
                icon: Icons.receipt_long_outlined,
                label: 'Riwayat Pesanan',
                onTap: () => _snack(context, 'Riwayat Pesanan'),
              ),
              _MenuTile(
                icon: Icons.credit_card_outlined,
                label: 'Metode Pembayaran',
                onTap: () => _snack(context, 'Metode Pembayaran'),
              ),
              _MenuTile(
                icon: Icons.shopping_bag_outlined,
                label: 'Pesanan Jumlah Besar',
                badge: 'Baru',
                onTap: () => _snack(context, 'Pesanan Jumlah Besar'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle('Roti Gembung Panglima'),
          _MenuCard(
            children: [
              _MenuTile(
                icon: Icons.help_outline,
                label: 'Bantuan',
                onTap: () => _snack(context, 'Bantuan'),
              ),
              _MenuTile(
                icon: Icons.menu_book_outlined,
                label: 'Kebijakan Privasi',
                onTap: () => _snack(context, 'Kebijakan Privasi'),
              ),
              _MenuTile(
                icon: Icons.info_outline,
                label: 'Ketentuan Layanan',
                onTap: () => _snack(context, 'Ketentuan Layanan'),
              ),
              _MenuTile(
                icon: Icons.mail_outline,
                label: 'Lapor Masalah',
                onTap: () => _snack(context, 'Lapor Masalah'),
              ),
              _MenuTile(
                icon: Icons.chat_outlined,
                label: 'Layanan WhatsApp',
                onTap: () => _snack(context, 'Layanan WhatsApp'),
              ),
              _MenuTile(
                icon: Icons.favorite_border,
                label: 'Tentang Aplikasi',
                onTap: () => _snack(context, 'Tentang Aplikasi'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: () => _snack(context, 'Keluar (dummy)'),
              icon: const Icon(Icons.logout, color: AppColors.error, size: 18),
              label: const Text(
                'Keluar',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Versi Aplikasi 1.0.0',
              style: TextStyle(fontSize: 12, color: AppColors.grey400),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// =============================================================================
// HEADER: avatar + edit + kartu sapaan (level & poin)
// =============================================================================

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final scheme = Theme.of(context).colorScheme;
    final profile = DummyData.profile;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.yellow100, AppColors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.primary, width: 2),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.white,
                  child: Text(
                    profile.avatarEmoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sapaan "Hai, {nama}" kini di samping foto.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hai,',
                      style: TextStyle(fontSize: 13, color: AppColors.grey600),
                    ),
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _snack(context, 'Edit Profil'),
                icon: Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: scheme.primary,
                ),
                label: Text(
                  'Edit Profil',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _StatsCard(),
        ],
      ),
    );
  }
}

/// Kartu statistik ringkas: hanya **VIP (level)** & **Panglima Points**.
class _StatsCard extends StatelessWidget {
  const _StatsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatBlock(
                label: 'VIP',
                icon: Icons.workspace_premium,
                iconColor: AppColors.gold500,
                value: '${DummyData.loyaltyTier} ${DummyData.loyaltyPercent}%',
              ),
            ),
            const VerticalDivider(width: 16),
            Expanded(
              child: _StatBlock(
                label: 'Panglima Points',
                icon: Icons.stars_rounded,
                iconColor: AppColors.gold500,
                value: '${DummyData.poin} pts',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.value,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: AppColors.grey600),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// DAILY CHECK-IN
// =============================================================================

class _DailyCheckIn extends StatelessWidget {
  const _DailyCheckIn();

  static const List<({String top, String label, bool voucher})> _days = [
    (top: '+25', label: 'Check-In', voucher: false),
    (top: '+25', label: 'Hari ke-2', voucher: false),
    (top: 'Voucher', label: 'Hari ke-3', voucher: true),
    (top: '+25', label: 'Hari ke-4', voucher: false),
    (top: '+25', label: 'Hari ke-5', voucher: false),
    (top: 'Voucher', label: 'Hari ke-6', voucher: true),
    (top: '+50', label: 'Hari ke-7', voucher: false),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Daily Check-In',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                GestureDetector(
                  onTap: () => _snack(context, 'Detail Check-In'),
                  child: Text(
                    'Detail',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Berakhir 31 Jul 2026',
              style: TextStyle(fontSize: 12, color: AppColors.grey600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) =>
                    _CheckInChip(day: _days[i], active: i == 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckInChip extends StatelessWidget {
  const _CheckInChip({required this.day, required this.active});

  final ({String top, String label, bool voucher}) day;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: active
            ? scheme.primary.withValues(alpha: 0.10)
            : AppColors.grey100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? scheme.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            day.voucher ? Icons.card_giftcard : Icons.monetization_on,
            color: day.voucher ? AppColors.grey400 : AppColors.gold500,
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            day.top,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            day.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: AppColors.grey600),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// GRUP MENU
// =============================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey100),
        ),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 56, endIndent: 16),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Widget di kanan (mis. Switch). Bila null, tampil chevron.
  final Widget? trailing;

  /// Badge kecil (mis. "Baru").
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.grey600),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: trailing ?? _defaultTrailing(context),
    );
  }

  Widget _defaultTrailing(BuildContext context) {
    final chevron = Icon(
      Icons.chevron_right,
      color: Theme.of(context).colorScheme.primary,
    );
    if (badge == null) return chevron;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.maroon700,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            badge!,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        chevron,
      ],
    );
  }
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
  );
}
