/// Biaya & tarif checkout (dummy, sementara sebelum backend / integrasi Grab).
///
/// Nilai ongkir Instant Delivery di sini hanya placeholder; nantinya diganti
/// dengan estimasi nyata dari API Grab saat memilih pembayaran.
class Fees {
  Fees._();

  /// Nilai belanja terkecil yang boleh dibayarkan. **0 = tanpa batas.**
  ///
  /// Diperiksa terhadap **isi keranjang**, sebelum biaya admin — biaya admin
  /// bergantung metode pembayaran yang belum dipilih pada tahap itu, jadi
  /// tidak bisa ikut dihitung.
  ///
  /// Batas Rp 50.000 dimatikan atas permintaan. Seluruh tampilannya tetap ada
  /// dan menyesuaikan nilai ini sendiri — isikan nominalnya lagi untuk
  /// menghidupkan kembali, tanpa menyentuh berkas lain.
  static const int minimumBelanja = 0;

  /// True bila batas minimum sedang berlaku.
  static bool get minimumBerlaku => minimumBelanja > 0;

  /// Ongkir Instant Delivery (flat, dummy).
  static const int instantDelivery = 10500;

  /// Biaya kemasan untuk pesanan delivery.
  static const int takeAwayCharge = 1500;

  /// Biaya kantung belanja opsional (pickup).
  static const int kantungBelanja = 1000;

  /// Estimasi waktu pengiriman Instant Delivery.
  static const String deliveryEta = '25 - 40 min';

  /// Ambang belanja untuk mendapat diskon ongkir (upsell).
  static const int freeOngkirThreshold = 120000;

  /// Panglima Points (cashback) yang didapat dari [subtotal].
  static int loyaltyCashback(int subtotal) => (subtotal * 0.045).round();
}
