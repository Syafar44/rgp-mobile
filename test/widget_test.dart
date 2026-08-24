// Smoke test dasar untuk aplikasi Roti Gembung Panglima.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roti_gembung_panglima_app/app.dart';
import 'package:roti_gembung_panglima_app/data/cart_store.dart';
import 'package:roti_gembung_panglima_app/data/dummy/dummy_data.dart';
import 'package:roti_gembung_panglima_app/widgets/cart_bar.dart';

void main() {
  testWidgets('Beranda tampil & navigasi antar tab bekerja',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    // Konten Beranda bagian atas tampil. Delivery/Pickup ada di dua tempat
    // (di bawah kartu & versi di dalam kartu yang tersembunyi saat expanded).
    expect(find.text('Delivery'), findsWidgets);
    expect(find.text('Pickup'), findsWidgets);
    expect(find.text('Gold 10%'), findsOneWidget);

    // Tarik-untuk-refresh terpasang (tiap tab dibungkus RefreshIndicator).
    expect(find.byType(RefreshIndicator), findsWidgets);

    // Scroll ke atas: header menciut (loyalty/alamat/"Melayani" hilang,
    // Delivery/Pickup pindah ke dalam kartu). Pastikan tak ada overflow.
    // `.first`: VIP juga memakai CustomScrollView (dibangun IndexedStack),
    // jadi targetkan milik Beranda yang tampil.
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delivery'), findsWidgets);

    // Lima tab navigasi tersedia.
    expect(find.byType(NavigationDestination), findsNWidgets(5));

    // Pindah ke tab Menu.
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    // Outlet selector, tab kategori, dan produk tampil.
    expect(find.text('Panglima Cabang Samarinda'), findsOneWidget);
    expect(find.text('Promo & Combo'), findsWidgets);
    expect(find.text('Kopi Panglima'), findsWidgets);

    // Pindah ke tab Profile.
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Daily Check-In'), findsOneWidget);
    expect(find.text('Panglima Points'), findsOneWidget);
  });

  testWidgets('Tombol lokasi membuka halaman Outlet Panglima',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    // Ketuk selektor outlet → halaman Outlet Panglima (hanya outlet, tanpa
    // tab Pickup/Delivery).
    await tester.tap(find.text('Panglima Cabang Samarinda'));
    await tester.pumpAndSettle();
    expect(find.text('Outlet Panglima'), findsOneWidget);
    expect(find.text('Panglima Cabang Balikpapan'), findsWidgets);

    // Pilih outlet lain → kembali ke Menu dengan outlet terpilih.
    await tester.tap(find.text('Panglima Cabang Balikpapan').first);
    await tester.pumpAndSettle();
    expect(find.text('Panglima Cabang Balikpapan'), findsWidgets);
  });

  testWidgets('Alamat Pengiriman: halaman sendiri + buka form',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    // Buka halaman Alamat Pengiriman dari menu Profile.
    final addr = find.text('Alamat Pengiriman');
    await tester.ensureVisible(addr);
    await tester.pumpAndSettle();
    await tester.tap(addr);
    await tester.pumpAndSettle();

    expect(find.text('Gunakan lokasi saat ini'), findsOneWidget);
    expect(find.text('Tambah Alamat Baru'), findsOneWidget);
    expect(find.text('Gerai panglima'), findsWidgets);

    // Buka form via alamat tersimpan (tanpa memicu GPS/jaringan).
    await tester.tap(find.text('Gerai panglima').first);
    await tester.pumpAndSettle();
    expect(find.text('Detail Alamat'), findsOneWidget);
    expect(find.text('Lanjutkan'), findsOneWidget);
  });

  testWidgets('Tab VIP menampilkan tier & tab voucher/pack/benefit',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    // 'VIP' juga jadi label di kartu Profile, jadi targetkan tab navbar.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('VIP'),
      ),
    );
    await tester.pumpAndSettle();

    // Header VIP & tier aktif (Gold) tampil.
    expect(find.text('Panglima VIP'), findsOneWidget);
    expect(find.text('GOLD'), findsWidgets);

    // Tiga tab tersedia; default Voucher → daftar voucher tampil.
    expect(find.text('Voucher'), findsWidgets);
    expect(find.text('Voucher Pack'), findsOneWidget);
    expect(find.text('Benefit'), findsOneWidget);
    expect(find.text('Voucher Tersedia'), findsOneWidget);

    // Pindah ke tab Benefit → keuntungan tier Gold tampil.
    await tester.tap(find.text('Benefit'));
    await tester.pumpAndSettle();
    expect(find.text('Cashback 10%'), findsOneWidget);

    // Pindah ke tab Voucher Pack → paket langganan tampil.
    await tester.tap(find.text('Voucher Pack'));
    await tester.pumpAndSettle();
    expect(find.text('Tersedia'), findsOneWidget);
    expect(find.text('Langganan Voucher Rp9.000'), findsOneWidget);
  });

  testWidgets('Bilah keranjang membuka Konfirmasi Pesanan (tanpa Dine-In)',
      (WidgetTester tester) async {
    // Isi keranjang lebih dulu agar bilah keranjang tampil.
    cartStore.add(DummyData.products.first, qty: 2);
    addTearDown(cartStore.clear);

    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    // Bilah keranjang tampil di atas navbar.
    expect(find.byType(CartBar), findsOneWidget);

    // Buka halaman Konfirmasi Pesanan.
    await tester.tap(find.byType(CartBar));
    await tester.pumpAndSettle();

    expect(find.text('Konfirmasi Pesanan'), findsOneWidget);
    expect(find.text('Pickup'), findsWidgets);
    expect(find.text('Delivery'), findsWidgets);
    // Metode Dine-In sengaja tidak ada.
    expect(find.text('Dine-In'), findsNothing);
    expect(find.text('Pilih Pembayaran'), findsOneWidget);

    // Tab Delivery: outlet sumber + lokasi + Instant Delivery tampil
    // (pemilihan kurir/ongkir final ditangani nanti via API Grab).
    await tester.tap(find.text('Delivery'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Outlet:'), findsOneWidget);
    expect(find.text('Alat Pengantaran'), findsNothing);
    expect(find.text('Instant Delivery'), findsOneWidget);

    // Kembali ke Pickup, lalu lanjut ke halaman Checkout via konfirmasi metode.
    await tester.tap(find.text('Pickup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih Pembayaran'));
    await tester.pumpAndSettle();
    expect(find.text('Ya, Sudah Benar'), findsOneWidget);

    await tester.tap(find.text('Ya, Sudah Benar'));
    await tester.pumpAndSettle();
    expect(find.text('Checkout'), findsOneWidget);
    expect(find.text('Pembayaran Langsung'), findsOneWidget);
    // Bottom bar Pickup: Jadwalkan + Bayar (selalu tampil).
    expect(find.text('Jadwalkan'), findsOneWidget);
    expect(find.textContaining('Bayar -'), findsOneWidget);
  });
}
