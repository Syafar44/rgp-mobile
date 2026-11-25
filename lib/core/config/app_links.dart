/// Tautan halaman web yang dirujuk dari dalam aplikasi.
///
/// Semuanya kosong sampai halamannya benar-benar terbit. Yang memakai wajib
/// memeriksa [ada] lebih dulu — menampilkan tautan yang menuju halaman kosong
/// lebih buruk daripada tidak menampilkannya sama sekali.
///
/// Kosong juga berarti menu terkaitnya tetap terkunci; lihat `AppFeatures`.
class AppLinks {
  const AppLinks._();

  /// Kebijakan hapus akun (`/hapus-akun`).
  ///
  /// Dirujuk dari layar penjelasan Hapus Akun, dan **wajib** diisikan juga ke
  /// kolom "Hapus URL akun" di Play Console — halaman ini harus bisa dibuka
  /// tanpa memasang aplikasi.
  static const String hapusAkun = '';

  /// Kebijakan privasi. Wajib ada sebelum terbit di Play Store.
  static const String kebijakanPrivasi = '';

  /// Ketentuan layanan.
  static const String ketentuanLayanan = '';

  /// Nomor WhatsApp layanan pelanggan ("Curhat" di Beranda), format
  /// internasional tanpa `+` — 08 222 000 2237.
  static const String whatsappLayanan = '6282220002237';

  /// Membuka chat [whatsappLayanan] — di aplikasi WhatsApp bila terpasang,
  /// di browser bila tidak.
  static Uri get whatsappChat => Uri.parse('https://wa.me/$whatsappLayanan');

  /// True bila [url] sudah diisi.
  static bool ada(String url) => url.trim().isNotEmpty;
}

/// Teks kebijakan yang menunggu jawaban Product/Finance.
///
/// **Masih sementara.** Brief backend (29 Sep 2026) menandainya sebagai
/// placeholder yang menunggu PRD Q3 & Q5. Selama nilainya masih bertanda
/// kurung siku, layar Hapus Akun menampilkannya apa adanya — memang dibuat
/// mencolok supaya tidak lolos ke rilis tanpa disadari, dan screenshot final
/// untuk Google belum boleh diambil.
class AppPolicy {
  const AppPolicy._();

  /// Berapa lama riwayat transaksi tetap disimpan setelah akun dihapus.
  ///
  /// Harus sama persis dengan halaman web hapus akun dan Kebijakan Privasi —
  /// reviewer Google membandingkan ketiganya.
  static const String retensiTransaksi = '10 tahun';

  /// True bila teks kebijakan masih berupa placeholder.
  static bool get masihDraf => retensiTransaksi.contains('[');
}
