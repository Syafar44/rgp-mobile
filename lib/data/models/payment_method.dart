/// Satu metode pembayaran dari `GET /payment/api/v2/payment-methods`.
///
/// Bentuk respons layanan ini berbeda dari endpoint POS: pembungkusnya
/// `{success, data}`, bukan `{message, data}`.
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.title,
    required this.value,
    required this.type,
    this.provider = '',
    this.file = '',
    this.addons = 0,
    this.percentage = 0,
    this.taxPercentage = 0,
  });

  final int id;

  /// Nama untuk ditampilkan, mis. "QRIS".
  final String title;

  /// Kode metode, mis. `qris` — nilai inilah yang dikirim saat pembayaran
  /// dibuat (endpointnya belum ada).
  final String value;

  /// Jenis metode, mis. `qris`. Dipakai memilih ikon.
  final String type;

  /// Penyedia di balik metode ini, mis. `sumopod`.
  final String provider;

  /// Logo metode. Bisa string kosong — tampilkan ikon bawaan bila begitu.
  final String file;

  /// Biaya tetap dalam Rupiah (mis. 300).
  final int addons;

  /// Biaya persentase dari nominal, dalam persen (`0.9` = 0,9%).
  final double percentage;

  /// Pajak atas biaya layanan, dalam persen (`11` = 11%).
  ///
  /// Dikenakan pada biaya, bukan pada nominal pesanan. Tanpa ini pratinjau
  /// biaya di kartu metode akan selalu kurang dari yang benar-benar ditagih.
  final double taxPercentage;

  bool get hasFee => addons > 0 || percentage > 0;

  bool get hasLogo => file.trim().isNotEmpty;

  /// Pratinjau biaya layanan untuk nominal [amount] (Rupiah, dibulatkan).
  ///
  /// Rumusnya mengikuti server: `(tetap + persentase × nominal) + pajak`.
  /// Tetap hanya pratinjau — angka yang ditagih selalu diambil dari
  /// `POST /payment-methods/calculate`.
  int feeFor(int amount) {
    final base = addons + (amount * percentage / 100);
    return (base * (1 + taxPercentage / 100)).round();
  }

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
    id: _int(json['id']) ?? 0,
    title: (json['title'] ?? json['name'] ?? '').toString(),
    value: (json['value'] ?? '').toString(),
    type: (json['type'] ?? '').toString(),
    provider: (json['provider'] ?? '').toString(),
    file: (json['file'] ?? '').toString(),
    addons: _int(json['addons']) ?? 0,
    percentage: _double(json['percentage']) ?? 0,
    taxPercentage: _double(json['tax_percentage']) ?? 0,
  );
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}

double? _double(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
