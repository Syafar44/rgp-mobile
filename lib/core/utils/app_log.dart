import 'package:flutter/foundation.dart';

/// Tingkat kepentingan satu baris log.
enum LogLevel {
  /// Jejak alur biasa.
  info('i'),

  /// Keadaan tidak wajar yang masih ditangani.
  warn('!'),

  /// Kegagalan.
  error('x');

  const LogLevel(this.mark);

  final String mark;
}

/// Satu baris log.
class LogEntry {
  LogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
    this.detail,
  });

  final DateTime time;
  final LogLevel level;

  /// Pengelompok, mis. `NET`, `CHECKOUT`, `PAY`, `ORDER`.
  final String tag;

  final String message;

  /// Isi tambahan (body respons, dsb.) — ditampilkan di baris terpisah.
  final String? detail;

  String get clock {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}'
        '.${time.millisecond.toString().padLeft(3, '0')}';
  }

  String get _head => '$clock ${level.mark} [$tag] $message';

  /// Versi lengkap — dipakai halaman Log & tombol salin.
  @override
  String toString() => detail == null ? _head : '$_head\n    $detail';

  /// Versi pendek untuk konsol.
  ///
  /// Konsol dipakai untuk mengikuti alur, bukan membaca body respons; body
  /// utuhnya dibaca dari halaman Log. Tanpa pemotongan ini satu respons daftar
  /// menu bisa menenggelamkan seluruh jejak di layar terminal.
  String toConsole() =>
      detail == null ? _head : '$_head\n    ${logTrim(detail)}';
}

/// Log aplikasi untuk penelusuran masalah.
///
/// Dua tujuan sekaligus:
/// - dicetak ke konsol saat debug (`flutter run`), dan
/// - disimpan di memori supaya bisa dibaca & disalin dari dalam aplikasi
///   lewat halaman Log — berguna saat menguji di HP, ketika konsol tidak
///   selalu terjangkau.
///
/// Mati total pada rilis: [enabled] mengikuti [kDebugMode], jadi tidak ada
/// data yang tertahan di memori pengguna.
class AppLog {
  AppLog._();

  static const bool enabled = kDebugMode;

  /// Batas jumlah baris yang disimpan; yang tertua dibuang lebih dulu.
  static const int maxEntries = 400;

  /// Batas panjang `detail` yang DISIMPAN di memori.
  ///
  /// Jauh lebih longgar dari pemotongan konsol supaya body respons API bisa
  /// dibaca utuh dari halaman Log — itu justru gunanya. Tetap dibatasi agar
  /// 400 baris log tidak menggelembungkan memori bila ada respons raksasa.
  static const int maxDetail = 20000;

  static final List<LogEntry> _entries = [];

  /// Bertambah tiap ada baris baru — dipakai halaman Log untuk menggambar
  /// ulang tanpa perlu state management tambahan.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Salinan baris log, terbaru di atas.
  static List<LogEntry> get entries => List.unmodifiable(_entries.reversed);

  static void info(String tag, String message, {String? detail}) =>
      _add(LogLevel.info, tag, message, detail);

  static void warn(String tag, String message, {String? detail}) =>
      _add(LogLevel.warn, tag, message, detail);

  static void error(String tag, String message, {String? detail}) =>
      _add(LogLevel.error, tag, message, detail);

  static void clear() {
    _entries.clear();
    revision.value++;
  }

  /// Seluruh log sebagai teks — untuk disalin & dikirim.
  static String dump() => entries.map((e) => e.toString()).join('\n');

  static void _add(
    LogLevel level,
    String tag,
    String message,
    String? detail,
  ) {
    if (!enabled) return;
    final entry = LogEntry(
      time: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      detail: detail == null ? null : logTrim(detail, max: maxDetail),
    );
    _entries.add(entry);
    if (_entries.length > maxEntries) _entries.removeAt(0);
    revision.value++;
    debugPrint(entry.toConsole());
  }
}

/// Potong teks panjang agar log tetap terbaca.
String logTrim(Object? value, {int max = 700}) {
  final text = value?.toString() ?? 'null';
  if (text.length <= max) return text;
  return '${text.substring(0, max)}… (${text.length} karakter)';
}

/// Sembunyikan nilai rahasia sebelum masuk log.
///
/// Log sering ditempelkan ke chat atau tiket; token dan API key tidak boleh
/// ikut tersebar karena keduanya cukup untuk memakai akun & gateway.
String redact(String? value) {
  if (value == null || value.isEmpty) return '';
  if (value.length <= 8) return '•••';
  return '${value.substring(0, 4)}…${value.substring(value.length - 4)}';
}
