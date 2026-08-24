/// Konfigurasi environment aplikasi.
///
/// Untuk sekarang nilainya di-hardcode karena data masih memakai dummy
/// (lihat `lib/data/dummy/`). Saat integrasi API sudah siap, pindahkan
/// nilai ini ke `.env` + paket `flutter_dotenv` seperti pada project svp_app.
class Env {
  /// Base URL API. Ganti dengan endpoint asli saat sudah tersedia.
  static const String baseUrl = 'https://api.panglima.example.com';

  /// API key umum (header `apikey`).
  static const String apiKey = 'REPLACE_WITH_API_KEY';

  /// True selama aplikasi masih memakai data dummy lokal.
  static const bool useDummyData = true;
}
