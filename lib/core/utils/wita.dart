/// Bantuan waktu WITA (UTC+8).
///
/// Seluruh waktu di API aplikasi customer memakai WITA dengan offset asli
/// (`+08:00`), berbeda dari `verified_at` pada API pendaftaran yang berakhiran
/// `Z` menyesatkan. Jam ambil pesanan mengacu pada jam **outlet**, bukan jam
/// perangkat — jadi nilai selalu ditampilkan & dikirim dalam WITA walaupun HP
/// pembeli berada di zona lain (WIB/WIT).
///
/// Nilai WITA diwakili sebagai `DateTime` polos (bukan UTC) yang isinya adalah
/// **jam dinding WITA**. Jangan panggil `toLocal()`/`toUtc()` pada nilai ini.
library;

const Duration _witaOffset = Duration(hours: 8);

/// Jam dinding WITA saat ini.
DateTime nowWita() => _stripUtc(DateTime.now().toUtc().add(_witaOffset));

/// Ubah [instant] (zona mana pun) menjadi jam dinding WITA.
DateTime toWita(DateTime instant) =>
    _stripUtc(instant.toUtc().add(_witaOffset));

/// Baca waktu dari API (RFC3339 ber-offset) menjadi jam dinding WITA.
/// Null bila [raw] kosong atau tidak bisa dibaca.
DateTime? parseWita(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(raw.trim());
  return parsed == null ? null : toWita(parsed);
}

/// Format jam dinding WITA untuk dikirim ke API: `2026-09-14T15:00:00+08:00`.
String rfc3339Wita(DateTime witaWallClock) {
  final d = witaWallClock;
  return '${d.year.toString().padLeft(4, '0')}-'
      '${_dua(d.month)}-${_dua(d.day)}T'
      '${_dua(d.hour)}:${_dua(d.minute)}:${_dua(d.second)}+08:00';
}

/// Jam saja, mis. `15:00`.
String formatJamWita(DateTime witaWallClock) =>
    '${_dua(witaWallClock.hour)}:${_dua(witaWallClock.minute)}';

/// Buang penanda UTC tanpa menggeser nilainya — hasilnya jam dinding WITA.
DateTime _stripUtc(DateTime utcShifted) => DateTime(
  utcShifted.year,
  utcShifted.month,
  utcShifted.day,
  utcShifted.hour,
  utcShifted.minute,
  utcShifted.second,
);

String _dua(int n) => n.toString().padLeft(2, '0');
