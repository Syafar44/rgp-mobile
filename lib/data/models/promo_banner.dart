/// Banner promo untuk carousel di Beranda.
///
/// Tampil sebagai foto (dummy dari sumber gambar gratis) dengan overlay
/// gradien gelap agar teks tetap terbaca, mengikuti gaya banner promo
/// aplikasi kopi/bakery pada umumnya.
class PromoBanner {
  const PromoBanner({
    required this.label,
    required this.title,
    required this.highlight,
    required this.subtitle,
    required this.imageUrl,
    this.badges = const [],
  });

  /// Label kecil di atas (mis. "SETIAP HARI").
  final String label;

  /// Judul (mis. "Diskon Spesial").
  final String title;

  /// Angka besar penarik perhatian (mis. "hingga 30%").
  final String highlight;

  /// Penjelasan singkat di bawah [highlight].
  final String subtitle;

  /// Foto latar banner.
  final String imageUrl;

  /// Badge kecil tambahan (mis. "Disc 20% Semua Menu").
  final List<String> badges;
}
