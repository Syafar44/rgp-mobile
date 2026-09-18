import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_colors.dart';
import 'data/notifiers.dart';
import 'data/outlet_store.dart';
import 'pages/beranda_page.dart';
import 'pages/history_page.dart';
import 'pages/menu_page.dart';
import 'pages/outlet_page.dart';
import 'pages/profile_page.dart';
import 'pages/vip_page.dart';
import 'widgets/cart_bar.dart';
import 'widgets/navbar_widget.dart';

/// Kerangka utama aplikasi: halaman aktif + bottom navigation.
///
/// Tab utama sengaja TIDAK memakai AppBar (Beranda menggambar header sendiri).
/// Halaman aktif ditentukan oleh [selectedPageNotifier]. Memakai [IndexedStack]
/// agar state tiap halaman (scroll, filter) tetap terjaga.
///
/// **Menu butuh outlet dulu.** Menu membutuhkan `id` outlet untuk memuat daftar
/// menu (`/outlets/:id/menus`), jadi berpindah ke tab Menu tanpa outlet terpilih
/// dibatalkan & pengguna diminta memilih outlet lewat modal.
class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  static const int _menuIndex = 1;

  static const List<Widget> _pages = [
    BerandaPage(),
    MenuPage(),
    VipPage(),
    _MainPage(title: 'History', child: HistoryPage()),
    ProfilePage(),
  ];

  /// Tab terakhir SELAIN Menu — tujuan "batal" saat Menu digagalkan.
  int _lastNonMenu = 0;
  bool _promptOpen = false;

  @override
  void initState() {
    super.initState();
    selectedPageNotifier.addListener(_guardMenu);
  }

  @override
  void dispose() {
    selectedPageNotifier.removeListener(_guardMenu);
    super.dispose();
  }

  /// Cegah masuk tab Menu bila belum ada outlet terpilih.
  void _guardMenu() {
    final page = selectedPageNotifier.value;
    if (page != _menuIndex) {
      _lastNonMenu = page;
      return;
    }
    if (outletStore.hasOutlet || _promptOpen) return;

    // Batalkan pindah ke Menu, lalu minta pilih outlet dulu.
    selectedPageNotifier.value = _lastNonMenu;
    _promptOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _promptOutlet();
    });
  }

  Future<void> _promptOutlet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => _OutletRequiredSheet(onPick: _pickOutletThenMenu),
    );
    _promptOpen = false;
  }

  Future<void> _pickOutletThenMenu() async {
    final outlet = await Navigator.push<Outlet>(
      context,
      MaterialPageRoute(builder: (_) => const OutletPage()),
    );
    if (!mounted || outlet == null) return;
    outletStore.select(outlet);
    Navigator.of(context).pop(); // tutup modal
    selectedPageNotifier.value = _menuIndex; // kini boleh ke Menu
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: selectedPageNotifier,
      builder: (context, selectedPage, child) {
        // Tab utama berlatar terang & tanpa AppBar → paksa ikon status bar
        // hitam (halaman ber-AppBar maroon/putih atur sendiri lewat AppBar).
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
          ),
          child: Scaffold(
            body: IndexedStack(index: selectedPage, children: _pages),
            // Bilah keranjang selalu tampil di atas navbar saat keranjang berisi.
            bottomNavigationBar: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [CartBar(), NavbarWidget()],
            ),
          ),
        );
      },
    );
  }
}

/// Modal instruksi: pilih outlet dulu sebelum melihat menu.
class _OutletRequiredSheet extends StatelessWidget {
  const _OutletRequiredSheet({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.maroon50,
              ),
              child: const Icon(
                Icons.storefront,
                size: 32,
                color: AppColors.maroon700,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pilih Outlet Dulu',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih outlet Panglima terdekat lebih dulu untuk melihat menu & '
              'harga yang tersedia.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.grey600),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.location_on_outlined, size: 20),
                label: const Text(
                  'Pilih Outlet',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

/// Pembungkus tab utama non-Beranda: SafeArea + judul sederhana.
class _MainPage extends StatelessWidget {
  const _MainPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
