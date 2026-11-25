import 'package:package_info_plus/package_info_plus.dart';

/// Versi aplikasi yang sedang terpasang, dibaca dari paket — sumbernya
/// `version:` di `pubspec.yaml` saat build (mis. `1.0.2+4`).
///
/// Jadi tidak ada lagi angka versi yang ditulis tangan di tampilan: cukup
/// naikkan `version:` di pubspec setiap rilis.
class AppVersion {
  AppVersion._();

  static String _label = '';

  /// Mis. `1.0.2 (4)` — versionName lalu versionCode. Kosong bila belum
  /// dimuat (mis. di test tanpa [load]).
  static String get label => _label;

  /// Dipanggil sekali di `main()`.
  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _label = format(info.version, info.buildNumber);
    } catch (_) {
      // Plugin tidak tersedia — tulisan versi cukup tidak ditampilkan.
    }
  }

  /// `1.0.2` + `4` → `1.0.2 (4)`.
  static String format(String version, String buildNumber) {
    final v = version.trim();
    final b = buildNumber.trim();
    if (v.isEmpty) return '';
    return b.isEmpty ? v : '$v ($b)';
  }
}
