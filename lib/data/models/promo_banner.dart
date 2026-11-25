/// Banner promo untuk carousel di Beranda.
///
/// Banner dibuat sebagai **gambar jadi** — judul, penawaran, dan kontak sudah
/// menyatu di dalam desainnya. Karena itu aplikasi hanya menampilkan
/// gambarnya utuh, tanpa menimpakan teks apa pun yang akan bertabrakan.
class PromoBanner {
  const PromoBanner({required this.image, this.label = ''});

  /// Gambar banner: path aset lokal atau URL (bila nanti dari server).
  final String image;

  /// Keterangan singkat isi banner — tidak ditampilkan, dipakai pembaca layar.
  final String label;

  /// True bila [image] harus diambil dari jaringan.
  bool get isNetwork =>
      image.startsWith('http://') || image.startsWith('https://');
}
