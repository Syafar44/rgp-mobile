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

  /// Kunci layanan pembayaran (`/payment/api/v2/...`).
  ///
  /// Sengaja terpisah dari [apiKey]: layanan pembayaran memakai kunci sendiri
  /// dan header yang berbeda (`X-API-Key`, bukan `apikey`).
  static String get paymentApiKey => _read('API_KEY_PAYMENT');

  /// App ID OneSignal (push notification).
  ///
  /// Bukan rahasia — nilainya memang tertanam di aplikasi — tapi tetap ditaruh
  /// di `.env` supaya app dev & produksi bisa dibedakan tanpa mengubah kode.
  static String get oneSignalAppId => _read('ONESIGNAL_APP_ID');

  /// False bila `.env` belum diisi/dimuat — dipakai untuk memberi pesan yang
  /// jelas ketimbang membiarkan request gagal dengan galat jaringan samar.
  static bool get isConfigured => baseUrl.isNotEmpty && apiKey.isNotEmpty;

  /// True bila push notification bisa dinyalakan.
  static bool get isPushConfigured => oneSignalAppId.isNotEmpty;

  /// True bila `DELETE /customer/account` sudah tersedia di server.
  ///
  /// Selama false, halaman Hapus Akun berjalan sebagai tiruan: alurnya utuh
  /// dan pembeli benar-benar dikeluarkan, tetapi tidak ada permintaan yang
  /// dikirim. Ubah ke `DELETE_ACCOUNT_LIVE=true` di `.env` begitu tim backend
  /// menyediakan endpointnya — tanpa menyentuh kode.
  static bool get isAccountDeletionLive =>
      _read('DELETE_ACCOUNT_LIVE').toLowerCase() == 'true';

  /// True bila endpoint Ganti Item Tidak Tersedia sudah tersedia di server.
  ///
  /// Selama false, modul ini berjalan sebagai tiruan: item habis hanya bisa
  /// dipicu dari menu debug, pilihan pembeli disimpan di HP, dan pembayaran
  /// selisihnya tidak membuat tagihan sungguhan. Ubah ke
  /// `ITEM_SWAP_LIVE=true` di `.env` begitu backend siap.
  static bool get isItemSwapLive =>
      _read('ITEM_SWAP_LIVE').toLowerCase() == 'true';

  /// True bila kunci layanan pembayaran sudah diisi.
  static bool get isPaymentConfigured =>
      baseUrl.isNotEmpty && paymentApiKey.isNotEmpty;
}
