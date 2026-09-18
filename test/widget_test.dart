// Smoke test dasar untuk aplikasi Roti Gembung Panglima.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roti_gembung_panglima_app/app.dart';
import 'package:roti_gembung_panglima_app/data/auth_store.dart';
import 'package:roti_gembung_panglima_app/data/cart_store.dart';
import 'package:roti_gembung_panglima_app/data/models/cart.dart';
import 'package:roti_gembung_panglima_app/data/models/outlet.dart';
import 'package:roti_gembung_panglima_app/data/models/user_account.dart';
import 'package:roti_gembung_panglima_app/data/notifiers.dart';
import 'package:roti_gembung_panglima_app/data/outlet_store.dart';
import 'package:roti_gembung_panglima_app/widgets/cart_bar.dart';

/// Akun yang seolah-olah sudah masuk (hasil `/auth`), agar test bisa langsung
/// menguji isi aplikasi tanpa melewati alur login.
const _loggedInUser = UserAccount(
  id: '55',
  phone: '082250851457',
  name: 'Syafar',
  email: 'syafar@panglima.id',
  emailVerified: true,
);

/// Outlet terpilih (biar tab Menu tidak terkunci di test).
const _outletFixture = Outlet(
  id: 19,
  name: 'RGP Test Outlet',
  address: 'Jl. Test No. 1, Samarinda',
  distanceKm: 0.5,
);

void main() {
  // Aplikasi digembok login & Menu butuh outlet. Sebagian besar test butuh
  // keadaan sudah masuk, ada outlet terpilih, & mulai di tab Beranda; test
  // alur login/gate menimpanya sesuai kebutuhan.
  setUp(() {
    authStore.currentUser.value = _loggedInUser;
    outletStore.selected.value = _outletFixture;
    selectedPageNotifier.value = 0;
  });
  tearDown(() {
    authStore.currentUser.value = null;
    outletStore.selected.value = null;
  });

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

    // Tab Menu tampil dengan selektor outlet terpilih. (Isi menu dimuat dari
    // API — di test tanpa server, tampil status galat, bukan produk.)
    expect(find.text('RGP Test Outlet'), findsWidgets);

    // Pindah ke tab Profile (Akun) — sudah masuk → profil tampil.
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

    // Ketuk selektor outlet → halaman Outlet Panglima yang meminta lokasi lalu
    // memuat outlet dari API. Jangan pumpAndSettle: indikator "memuat" berputar
    // tanpa henti; pakai pump berdurasi.
    await tester.tap(find.text('RGP Test Outlet').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Outlet Panglima'), findsOneWidget);
  });

  testWidgets('Menu butuh outlet: modal muncul bila belum pilih',
      (WidgetTester tester) async {
    outletStore.selected.value = null; // belum pilih outlet (timpa setUp).

    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    // Dari Beranda, ketuk tab Menu → dibatalkan & modal instruksi muncul.
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Outlet Dulu'), findsOneWidget);
    expect(find.text('Pilih Outlet'), findsOneWidget); // tombol di modal
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
    // Isi keranjang server (palsu) lebih dulu agar bilah keranjang tampil.
    // Di test tanpa `.env`, pemuatan ulang dari server gagal diam-diam dan
    // isi ini dipertahankan (lihat CartStore.loadFor).
    cartStore.cart.value = const ServerCart(
      outletId: 19,
      items: [
        ServerCartItem(
          id: 1,
          menuId: 586,
          title: 'Roti Gembung Cokelat',
          menuType: 'single',
          quantity: 2,
          price: 8000,
          subtotal: 16000,
        ),
      ],
      total: 16000,
    );
    addTearDown(() => cartStore.cart.value = ServerCart.empty());

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
    // Outlet terpilih tampil di kartu sumber.
    expect(find.textContaining('Outlet:'), findsWidgets);

    // Tab Delivery: lokasi pengiriman + Instant Delivery tampil.
    await tester.tap(find.text('Delivery'));
    await tester.pumpAndSettle();
    expect(find.text('Alat Pengantaran'), findsNothing);
    expect(find.text('Instant Delivery'), findsOneWidget);
  });

  testWidgets('Daftar akun baru: dari halaman email → registrasi',
      (WidgetTester tester) async {
    authStore.currentUser.value = null; // mulai belum masuk (gerbang login).

    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    // Gerbang login (onboarding) tampil; belum bisa lihat menu.
    expect(find.text('Gabung Sekarang'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Gabung Sekarang → halaman email.
    await tester.tap(find.text('Gabung Sekarang'));
    await tester.pumpAndSettle();
    expect(find.text('Halo!'), findsOneWidget);

    // Isi email lalu "Daftar" → halaman registrasi (email terbawa). Tautan
    // Daftar ada di bawah, gulir dulu sampai terlihat.
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'budi@test.com',
    );
    await tester.pumpAndSettle();
    final daftar = find.text('Belum punya akun? Daftar');
    await tester.scrollUntilVisible(
      daftar,
      120,
      scrollable: find
          .ancestor(of: find.text('Halo!'), matching: find.byType(Scrollable))
          .first,
    );
    await tester.tap(daftar);
    await tester.pumpAndSettle();
    expect(find.text('Atur Kata Sandi'), findsOneWidget);

    // Email dari halaman sebelumnya sudah terisi.
    expect(find.widgetWithText(TextField, 'Email *'), findsOneWidget);

    // Kata sandi < 8 karakter ditolak (aturan `/register`) → tombol mati.
    await tester.enterText(
      find.widgetWithText(TextField, 'Nama Lengkap *'),
      'Budi Test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Email *'),
      'budi@test.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nomor Handphone *'),
      '081234567890',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Alamat *'),
      'Jl. Merdeka No. 10, Samarinda',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Kata Sandi *'),
      'abc123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Konfirmasi Kata Sandi *'),
      'abc123',
    );
    // Form kini lebih panjang (nomor HP & alamat), jadi gulir dulu sampai
    // checkbox & tombol benar-benar terbangun. `scrollable` ditunjuk eksplisit
    // karena banyak Scrollable lain di pohon (halaman di bawahnya + tiap
    // TextField punya Scrollable sendiri).
    final formScrollable = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;

    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      200,
      scrollable: formScrollable,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(FilledButton, 'Simpan dan Daftar');
    await tester.scrollUntilVisible(submit, 200, scrollable: formScrollable);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    // Kata sandi memenuhi aturan (>= 8 karakter, campur huruf & angka) →
    // tombol aktif. Penekanannya tidak diuji di sini karena `Simpan dan
    // Daftar` memanggil API (`POST /register` + `POST /auth`) yang butuh
    // server — uji ujung-ke-ujungnya perlu Dio yang di-mock.
    await tester.enterText(
      find.widgetWithText(TextField, 'Kata Sandi *'),
      'abcd1234',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Konfirmasi Kata Sandi *'),
      'abcd1234',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('Masuk: email + kata sandi dalam satu halaman',
      (WidgetTester tester) async {
    authStore.currentUser.value = null; // mulai belum masuk (gerbang login).

    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gabung Sekarang'));
    await tester.pumpAndSettle();

    // Satu halaman: kolom email + kata sandi bersama (tidak dipisah).
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Kata Sandi'), findsOneWidget);

    // Tombol "Masuk" mati sampai email valid & kata sandi terisi.
    final masuk = find.widgetWithText(FilledButton, 'Masuk');
    expect(tester.widget<FilledButton>(masuk).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'syafar@panglima.id',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(masuk).onPressed, isNull); // sandi kosong

    await tester.enterText(
      find.widgetWithText(TextField, 'Kata Sandi'),
      'panglima1',
    );
    await tester.pumpAndSettle();
    // Aktif. Penekanan tombol memanggil `POST /auth` (butuh server), tak diuji.
    expect(tester.widget<FilledButton>(masuk).onPressed, isNotNull);
    expect(authStore.isLoggedIn, isFalse);
  });
}
