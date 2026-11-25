import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/push/push_service.dart';
import 'core/theme/app_colors.dart';
import 'data/nearest_outlet.dart';
import 'data/notifiers.dart';
import 'data/order_store.dart';
import 'data/outlet_store.dart';
import 'pages/beranda_page.dart';
import 'pages/menu_page.dart';
import 'pages/outlet_page.dart';
import 'pages/orders_page.dart';
import 'pages/profile_page.dart';
import 'pages/vip_page.dart';
import 'widgets/active_order_bar.dart';
import 'widgets/cart_bar.dart';
import 'widgets/navbar_widget.dart';
import 'widgets/outlet_switch.dart';

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
    _OrdersTab(),
    ProfilePage(),
  ];

  /// Tab terakhir SELAIN Menu — tujuan "batal" saat Menu digagalkan.
  int _lastNonMenu = 0;
  bool _promptOpen = false;

  @override
  void initState() {
    super.initState();
    selectedPageNotifier.addListener(_guardMenu);
    // Dipanggil di sini, bukan di `main()`, supaya ikut jalan setelah pengguna
    // baru saja masuk — kerangka ini dibangun ulang tiap sesi dimulai.
    orderStore.refresh();
    _siapkanSesi();
  }

  /// Persiapan sekali jalan tiap sesi dimulai.
  ///
  /// Keduanya berpotensi memunculkan dialog izin sistem, jadi dijalankan
  /// **berurutan** — dua dialog yang menumpuk sekaligus membuat orang menekan
  /// "Tolak" tanpa membaca. Lokasi didahulukan karena hasilnya langsung
  /// terlihat di layar (outlet terisi sendiri), sehingga alasan aplikasi
  /// memintanya lebih mudah dipahami.
  Future<void> _siapkanSesi() async {
    // Menebak outlet terdekat supaya pembeli tidak wajib memilih manual.
    // Tidak meminta izin apa pun bila outletnya sudah ada.
    await autoSelectNearestOutlet();

    // Izin notifikasi diminta di sini, bukan saat aplikasi pertama dibuka:
    // pembeli yang sudah masuk lebih paham kenapa aplikasi ini perlu
    // memberitahunya (pesanan siap diambil). Tidak melakukan apa pun bila izin
    // sudah ada atau push dimatikan lewat `.env`.
    if (mounted) await pushService.askPermission();
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
    // Keranjang masih kosong di alur ini, tapi tetap lewat helper yang sama
    // supaya aturan "satu pembeli satu outlet" ditegakkan di satu tempat.
    if (!await switchOutlet(context, outlet) || !mounted) return;
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
              children: [ActiveOrderBar(), CartBar(), NavbarWidget()],
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

/// Tab "History" pada navigasi bawah: pesanan berjalan & riwayat.
class _OrdersTab extends StatelessWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Pesanan',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: OrdersTabs()),
        ],
      ),
    );
  }
}
