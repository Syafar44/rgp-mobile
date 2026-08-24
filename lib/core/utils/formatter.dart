import 'package:intl/intl.dart';

/// Formatter angka & tanggal untuk tampilan (Bahasa Indonesia).

final NumberFormat _rupiah =
    NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

/// Format nilai [value] menjadi Rupiah, mis. `Rp 12.000`.
String formatRupiah(int value) => _rupiah.format(value);

final NumberFormat _desimal = NumberFormat.decimalPattern('id');

/// Format angka dengan pemisah ribuan tanpa simbol, mis. `1.023.450`.
/// Dipakai untuk poin/level (halaman VIP).
String formatPoin(int value) => _desimal.format(value);

const List<String> _bulanSingkat = [
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _dua(int n) => n.toString().padLeft(2, '0');

/// Format tanggal+jam, mis. `6 Jul 2026, 08:15`.
String formatTanggal(DateTime d) =>
    '${d.day} ${_bulanSingkat[d.month]} ${d.year}, ${_dua(d.hour)}:${_dua(d.minute)}';
