/// Kumpulan path gambar bawaan aplikasi.
///
/// Semua aset gambar didaftarkan di sini agar mengganti foto cukup di satu
/// berkas. Foldernya sudah didaftarkan sekaligus di `pubspec.yaml`
/// (`assets/img/`), jadi menambah berkas baru tidak perlu menyentuh pubspec.
class AppImages {
  /// Foto outlet — halaman masuk & slide terakhir onboarding.
  static const String outlet = 'assets/img/outlet j2.jpg';

  /// Slide onboarding. Ketiganya 853 × 1280.
  static const String slide1 = 'assets/img/slide1.jpg';
  static const String slide2 = 'assets/img/slide2.jpg';
  static const String slide3 = 'assets/img/slide3.jpg';

  /// Banner promo Beranda. Sudah berisi teks & logo (banner jadi), jadi
  /// ditampilkan utuh tanpa overlay teks dari aplikasi.
  ///
  /// Sementara memakai aset lokal sampai API gambar dari backend siap.
  static const String banner1 = 'assets/img/banner1.jpg';
  static const String banner2 = 'assets/img/banner2.jpg';
  static const String banner3 = 'assets/img/banner3.jpg';

  /// Perbandingan lebar : tinggi banner promo.
  ///
  /// Dipakai menghitung tinggi carousel supaya banner tampil **utuh** — tanpa
  /// ini sisi kiri-kanan terpotong dan teks di tepi banner (nomor telepon,
  /// ikon media sosial) ikut hilang.
  ///
  /// Ketiga banner praktis serupa: banner1 & banner2 1280 × 533, banner3
  /// 1200 × 500 — selisih rasionya 0,1% sehingga satu nilai cukup. Bila nanti
  /// banner datang dari API dengan ukuran bebas, rasio ini harus ikut dari
  /// server, bukan dipatok di sini.
  static const double bannerAspect = 1280 / 533;
}
