import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/notifiers.dart';
import 'pages/beranda_page.dart';
import 'pages/history_page.dart';
import 'pages/menu_page.dart';
import 'pages/profile_page.dart';
import 'pages/vip_page.dart';
import 'widgets/cart_bar.dart';
import 'widgets/navbar_widget.dart';

/// Kerangka utama aplikasi: halaman aktif + bottom navigation.
///
/// Tab utama sengaja TIDAK memakai AppBar (Beranda menggambar header sendiri).
/// Halaman detail yang di-`push` nanti bisa memakai `AppTopBar`
/// (`lib/widgets/app_top_bar.dart`).
///
/// Halaman aktif ditentukan oleh [selectedPageNotifier]. Memakai
/// [IndexedStack] agar state tiap halaman (scroll, filter) tetap terjaga.
class WidgetTree extends StatelessWidget {
  const WidgetTree({super.key});

  static const List<Widget> _pages = [
    // Beranda & Menu: punya header sendiri (outlet/loyalty) → tanpa wrapper.
    BerandaPage(),
    MenuPage(),
    // VIP: menggambar top bar & kartu tier sendiri → tanpa wrapper.
    VipPage(),
    _MainPage(title: 'History', child: HistoryPage()),
    // Profile: header sapaan menjangkau status bar → tanpa wrapper.
    ProfilePage(),
  ];

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
