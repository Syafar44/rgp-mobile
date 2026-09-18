import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Konfigurasi environment aplikasi — dibaca dari file `.env` di root project
/// (pola sama dengan project svp_app).
///
/// `.env` dimuat sekali di `main()`. Isi file:
/// ```
/// BASE_URL=https://api.example.com
/// API_KEY=...
/// ```
/// File `.env` tidak di-commit (lihat `.gitignore`); contoh isian ada di
/// `.env.example`.
class Env {
  /// Baca satu kunci dengan aman.
  ///
  /// `dotenv.env` melempar `NotInitializedError` bila `dotenv.load()` belum
  /// pernah dipanggil (mis. di widget test), jadi selalu cek dulu.
  static String _read(String key) =>
      dotenv.isInitialized ? (dotenv.env[key]?.trim() ?? '') : '';

  /// Base URL API, tanpa garis miring di akhir.
  static String get baseUrl => _read('BASE_URL');

  /// API key aplikasi — dikirim sebagai header `apikey` (dipakai `/auth`).
  static String get apiKey => _read('API_KEY');

  /// False bila `.env` belum diisi/dimuat — dipakai untuk memberi pesan yang
  /// jelas ketimbang membiarkan request gagal dengan galat jaringan samar.
  static bool get isConfigured => baseUrl.isNotEmpty && apiKey.isNotEmpty;
}
