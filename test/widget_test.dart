// Smoke test dasar untuk aplikasi Roti Gembung Panglima.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roti_gembung_panglima_app/app.dart';
import 'package:roti_gembung_panglima_app/core/config/fees.dart';
import 'package:roti_gembung_panglima_app/core/utils/formatter.dart';
import 'package:roti_gembung_panglima_app/data/auth_store.dart';
import 'package:roti_gembung_panglima_app/data/cart_store.dart';
import 'package:roti_gembung_panglima_app/data/models/cart.dart';
import 'package:roti_gembung_panglima_app/data/models/order.dart';
import 'package:roti_gembung_panglima_app/data/models/outlet.dart';
import 'package:roti_gembung_panglima_app/data/models/user_account.dart';
import 'package:roti_gembung_panglima_app/data/notifiers.dart';
import 'package:roti_gembung_panglima_app/data/order_store.dart';
import 'package:roti_gembung_panglima_app/data/outlet_store.dart';
import 'package:roti_gembung_panglima_app/widgets/active_order_bar.dart';
import 'package:roti_gembung_panglima_app/widgets/cart_bar.dart';
import 'package:roti_gembung_panglima_app/widgets/soon_badge.dart';

/// Akun yang seolah-olah sudah masuk (hasil `/auth`), agar test bisa langsung
/// menguji isi aplikasi tanpa melewati alur login.
const _loggedInUser = UserAccount(
  id: '55',
  phone: '082250851457',
  name: 'Syafar',
  email: 'syafar@panglima.id',
  emailVerified: true,
);

/// Pesanan yang sedang berjalan — dipakai menguji aturan "satu pesanan pada
/// satu waktu". `orderStore.refresh()` gagal diam-diam tanpa server, jadi
/// nilai yang dipasang test inilah yang dibaca penjaganya.
const _pesananBerjalan = Order(
  id: 208569,
  documentNumber: 'APP1790152222661',
  outletId: 19,
  outletName: 'RGP Test Outlet',
  status: OrderStatus.appPaid,
  statusLabel: 'Sedang disiapkan',
  totalAmount: 3000,
  itemCount: 1,
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
    // Selama `AppFeatures.loyalty` mati, pill-nya berisi penanda — BUKAN
    // "Gold 10%" atau jumlah poin yang tidak dimiliki pembeli.
    expect(find.textContaining('Panglima Points'), findsWidgets);
    expect(find.text('Gold 10%'), findsNothing);

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
    // Kartu absen harian disembunyikan (`AppFeatures.dailyCheckIn`) karena
    // tidak pernah menyimpan apa pun.
    expect(find.text('Daily Check-In'), findsNothing);
    // Blok poin tetap ada sebagai penanda, tapi nilainya "Segera hadir".
    expect(find.text('Panglima Points'), findsOneWidget);
    expect(find.textContaining('pts'), findsNothing);
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

  testWidgets('Alamat Pengiriman terkunci selama delivery belum rilis',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    final addr = find.text('Alamat Pengiriman');
    await tester.ensureVisible(addr);
    await tester.pumpAndSettle();

    // Barisnya tetap terlihat (pembeli tahu fiturnya akan ada) tapi ditandai
    // terkunci — lihat `AppFeatures.alamatTersimpan`.
    expect(addr, findsOneWidget);
    expect(find.byType(SoonBadge), findsWidgets);

    // Ditekan pun tidak membuka apa-apa: lebih jujur daripada halaman berisi
    // alamat yang hanya tersimpan di HP dan hilang saat pasang ulang.
    await tester.tap(addr);
    await tester.pumpAndSettle();
    expect(find.text('Tambah Alamat Baru'), findsNothing);
  });

  testWidgets('Menu Profile yang belum rilis tidak ikut tampil',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    // Dihilangkan sepenuhnya — dulu semuanya hanya memunculkan snackbar.
    expect(find.text('Kotak Masuk'), findsNothing);
    expect(find.text('Scan Merchandise'), findsNothing);
    expect(find.text('Ubah Bahasa Aplikasi'), findsNothing);
    expect(find.text('Metode Pembayaran'), findsNothing);
    expect(find.text('Pesanan Jumlah Besar'), findsNothing);
    // Saklar biometrik ikut hilang: dulu bisa digeser padahal tidak mengunci
    // apa pun.
    expect(find.text('Aktifkan Biometric ID'), findsNothing);
    expect(find.byType(Switch), findsNothing);

    // Yang sungguhan tetap ada.
    expect(find.text('Ubah Kata Sandi'), findsOneWidget);

    // Wajib ada menurut kebijakan Google Play untuk aplikasi yang bisa
    // membuat akun: jalur penghapusan akun harus tersedia DI DALAM aplikasi.
    expect(find.text('Hapus Akun'), findsOneWidget);

    // Daftar menunya panjang, jadi yang di bawah perlu digulir dulu — tanpa
    // ini `ListView` belum membangunnya dan `find` mengira tidak ada.
    await tester.scrollUntilVisible(
      find.text('Pesanan Saya'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pesanan Saya'), findsOneWidget);
  });

  testWidgets('Email belum diverifikasi: boleh menjelajah, tak boleh memesan',
      (WidgetTester tester) async {
    // Akun yang sama persis, hanya emailnya belum diverifikasi.
    authStore.currentUser.value = const UserAccount(
      id: '55',
      phone: '082250851457',
      name: 'Syafar',
      email: 'syafar@panglima.id',
      emailVerified: false,
    );
    cartStore.cart.value = const ServerCart(
      outletId: 19,
      items: [
        ServerCartItem(
          id: 1,
          menuId: 586,
          title: 'Roti Gembung Cokelat',
          menuType: 'single',
          quantity: 7,
          price: 8000,
          subtotal: 56000,
        ),
      ],
      total: 56000,
    );
    addTearDown(() => cartStore.cart.value = ServerCart.empty());

    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    // Pintunya terbuka: menu & harga tetap bisa dilihat.
    expect(find.byType(NavigationBar), findsOneWidget);

    // Tapi langkah yang menghasilkan pesanan ditahan.
    await tester.tap(find.byType(CartBar));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih Pembayaran'));
    await tester.pumpAndSettle();

    expect(find.text('Verifikasi Email Dulu'), findsOneWidget);
    expect(find.text('Konfirmasi Pesanan'), findsOneWidget); // tidak berpindah

    await tester.tap(find.text('Nanti Saja'));
    await tester.pumpAndSettle();

    // Menambah isi keranjang pun ditahan oleh aturan yang sama.
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();
    expect(find.text('Verifikasi Email Dulu'), findsOneWidget);
  });

  testWidgets('Keluar akun minta konfirmasi dulu', (WidgetTester tester) async {
    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    final keluar = find.text('Keluar');
    await tester.scrollUntilVisible(
      keluar,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(keluar);
    await tester.pumpAndSettle();

    // Masih masuk — baru dialog yang muncul.
    expect(find.text('Keluar dari akun?'), findsOneWidget);
    expect(authStore.isLoggedIn, isTrue);

    // Batal → tetap di dalam aplikasi.
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(authStore.isLoggedIn, isTrue);

    // Ulangi lalu setujui → baru benar-benar keluar.
    await tester.tap(find.text('Keluar').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Keluar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(authStore.isLoggedIn, isFalse);
  });

  testWidgets('Tab VIP tampil sebagai "segera hadir", tanpa angka karangan',
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

    // Tabnya tetap ada di navbar; isinya yang diganti.
    expect(find.text('Panglima VIP'), findsOneWidget);
    expect(find.byType(SoonBadge), findsOneWidget);

    // Tidak ada satu pun data karangan yang tersisa — termasuk sapaan bernama
    // orang yang dulu tertulis mati di `DummyData.vipMemberName`.
    expect(find.text('GOLD'), findsNothing);
    expect(find.text('Voucher Pack'), findsNothing);
    expect(find.text('Cashback 10%'), findsNothing);
    expect(find.textContaining('Hai, '), findsNothing);
  });

  testWidgets('Beranda: Order membuka tab Menu, Delivery terkunci',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    // Delivery belum rilis → kartunya tidak bisa ditekan.
    await tester.tap(
      find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Delivery'),
      ).last,
    );
    await tester.pumpAndSettle();
    expect(selectedPageNotifier.value, 0, reason: 'Delivery tidak boleh pindah tab');

    // Order → tab Menu (dulu keliru mengarah ke tab VIP).
    await tester.tap(find.text('Order'));
    await tester.pumpAndSettle();
    expect(selectedPageNotifier.value, menuTabIndex);
  });

  testWidgets('Satu pesanan pada satu waktu: checkout kedua ditahan',
      (WidgetTester tester) async {
    cartStore.cart.value = const ServerCart(
      outletId: 19,
      items: [
        ServerCartItem(
          id: 1,
          menuId: 586,
          title: 'Roti Gembung Cokelat',
          menuType: 'single',
          // Di atas minimum belanja (Fees.minimumBelanja) supaya tombol
          // "Pilih Pembayaran" aktif dan penjaganya benar-benar teruji.
          quantity: 7,
          price: 8000,
          subtotal: 56000,
        ),
      ],
      total: 56000,
    );
    addTearDown(() {
      cartStore.cart.value = ServerCart.empty();
      orderStore.clear();
    });

    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CartBar));
    await tester.pumpAndSettle();

    // Pesanan lain muncul SETELAH halaman ini terbuka — inilah alasan
    // penjaganya diperiksa lagi di detik terakhir, bukan hanya saat masuk.
    // `orderStore.refresh()` di dalam penjaga gagal diam-diam tanpa server,
    // jadi nilai ini yang dipakai.
    orderStore.setActive([_pesananBerjalan]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih Pembayaran'));
    await tester.pumpAndSettle();

    // Ditahan sebelum halaman Checkout, lengkap dengan nomor pesanannya.
    expect(find.text('Masih Ada Pesanan Berjalan'), findsOneWidget);
    expect(find.text('APP1790152222661'), findsOneWidget);
    expect(find.text('Pilih Pembayaran'), findsOneWidget); // masih di keranjang
  });

  testWidgets('Batas minimum belanja menguncikan tombol Pilih Pembayaran',
      (WidgetTester tester) async {
    // Rp 8.000 — di bawah batas bila batasnya sedang berlaku.
    cartStore.cart.value = const ServerCart(
      outletId: 19,
      items: [
        ServerCartItem(
          id: 1,
          menuId: 586,
          title: 'Roti Gembung Cokelat',
          menuType: 'single',
          quantity: 1,
          price: 8000,
          subtotal: 8000,
        ),
      ],
      total: 8000,
    );
    addTearDown(() => cartStore.cart.value = ServerCart.empty());

    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CartBar));
    await tester.pumpAndSettle();

    final tombol = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Pilih Pembayaran'),
        matching: find.byType(FilledButton),
      ),
    );

    // Batasnya dimatikan pada build debug (lihat `Fees.minimumBelanja`), jadi
    // test ini menyesuaikan diri dengan konfigurasi yang sedang berlaku —
    // bukan perlu ditulis ulang tiap saklarnya dibalik.
    if (!Fees.minimumBerlaku) {
      expect(tombol.onPressed, isNotNull);
      expect(find.textContaining('Minimal transaksi'), findsNothing);
      return;
    }

    // Alasannya tertulis, lengkap dengan kekurangannya — bukan tombol mati
    // tanpa penjelasan.
    expect(find.textContaining('Minimal transaksi'), findsOneWidget);
    expect(
      find.textContaining(formatRupiah(Fees.minimumBelanja - 8000)),
      findsOneWidget,
    );
    expect(tombol.onPressed, isNull);

    await tester.tap(find.text('Pilih Pembayaran'));
    await tester.pumpAndSettle();
    expect(find.text('Konfirmasi Pesanan'), findsOneWidget); // tidak berpindah
  });

  testWidgets('Pesanan berjalan menyembunyikan bilah keranjang',
      (WidgetTester tester) async {
    cartStore.cart.value = const ServerCart(
      outletId: 19,
      items: [
        ServerCartItem(
          id: 1,
          menuId: 586,
          title: 'Roti Gembung Cokelat',
          menuType: 'single',
          // Di atas minimum belanja (Fees.minimumBelanja) supaya tombol
          // "Pilih Pembayaran" aktif dan penjaganya benar-benar teruji.
          quantity: 7,
          price: 8000,
          subtotal: 56000,
        ),
      ],
      total: 56000,
    );
    addTearDown(() {
      cartStore.cart.value = ServerCart.empty();
      orderStore.clear();
    });

    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    // Tanpa pesanan berjalan, bilah keranjang tampil seperti biasa.
    expect(find.byType(CartBar), findsOneWidget);
    expect(find.byType(ActiveOrderBar), findsOneWidget);
    expect(find.text('Lanjutkan pembayaran'), findsNothing);

    // Begitu ada pesanan berjalan, bilah keranjang menghilang — checkout
    // memang tertahan selama pesanan sebelumnya belum tuntas.
    orderStore.setActive([_pesananBerjalan]);
    await tester.pumpAndSettle();

    expect(find.text('7 produk'), findsNothing);
    expect(find.text('Lanjutkan pembayaran'), findsNothing); // app_paid
    expect(find.text('Pesanan sedang diproses'), findsOneWidget);

    // Pesanan diserahkan kasir → tidak lagi berjalan, keranjang kembali.
    orderStore.setActive([
      Order(
        id: _pesananBerjalan.id,
        documentNumber: _pesananBerjalan.documentNumber,
        outletId: 19,
        outletName: 'RGP Test Outlet',
        status: OrderStatus.active,
        statusLabel: 'Selesai',
        totalAmount: 3000,
        itemCount: 1,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Pesanan sedang diproses'), findsNothing);
    expect(find.text('7 produk'), findsOneWidget);
  });

  testWidgets('Pesanan belum dibayar: bilahnya mengajak melunasi',
      (WidgetTester tester) async {
    orderStore.setActive([
      Order(
        id: 0,
        documentNumber: 'APP1790555372184',
        outletId: 19,
        outletName: 'RGP Test Outlet',
        status: OrderStatus.pending,
        statusLabel: 'Menunggu pembayaran',
        totalAmount: 3000,
        itemCount: 1,
      ),
    ]);
    addTearDown(orderStore.clear);

    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();

    expect(find.text('Lanjutkan pembayaran'), findsOneWidget);
    expect(find.text('Bayar'), findsOneWidget);
    expect(find.text('Pesanan sedang diproses'), findsNothing);
  });

  testWidgets('Pesanan berjalan: menambah jumlah di keranjang ditahan',
      (WidgetTester tester) async {
    cartStore.cart.value = const ServerCart(
      outletId: 19,
      items: [
        ServerCartItem(
          id: 1,
          menuId: 586,
          title: 'Roti Gembung Cokelat',
          menuType: 'single',
          // Di atas minimum belanja (Fees.minimumBelanja) supaya tombol
          // "Pilih Pembayaran" aktif dan penjaganya benar-benar teruji.
          quantity: 7,
          price: 8000,
          subtotal: 56000,
        ),
      ],
      total: 56000,
    );
    addTearDown(() {
      cartStore.cart.value = ServerCart.empty();
      orderStore.clear();
    });

    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CartBar));
    await tester.pumpAndSettle();

    // Pesanan lain muncul selagi halaman keranjang terbuka.
    orderStore.setActive([_pesananBerjalan]);
    await tester.pumpAndSettle();

    // Tombol "+" pada baris keranjang (bukan "Tambah Pesanan" di judul
    // bagian, yang memakai ikon sama dan muncul lebih dulu).
    expect(find.byIcon(Icons.add), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();

    expect(find.text('Masih Ada Pesanan Berjalan'), findsOneWidget);
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

    // Tab Delivery terkunci selama endpoint ongkir & alamat belum ada:
    // ditekan tidak berpindah, jadi pembeli tidak mengisi segalanya lebih
    // dulu untuk kemudian menemui tombol Pesan yang mati.
    await tester.tap(find.text('Delivery'));
    await tester.pumpAndSettle();
    expect(find.text('Instant Delivery'), findsNothing);
    expect(find.text('Pilih Pembayaran'), findsOneWidget);
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
    // Digulir dulu: tinggi foto outlet di atas form bisa berubah sewaktu-waktu
    // dan ListView hanya membangun yang terlihat.
    final masuk = find.widgetWithText(FilledButton, 'Masuk');
    await tester.scrollUntilVisible(
      masuk,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
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
