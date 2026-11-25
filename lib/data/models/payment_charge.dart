/// Model pembayaran Midtrans (Core API) — lihat dokumen "API Pembayaran
/// Midtrans".
///
/// Menggantikan bentuk lama (Sumopod) yang memakai `payment_link_url`,
/// `fee`/`net_amount`, dan `expires_at`. Midtrans tidak mengirim ketiganya:
/// nominalnya hanya [PaymentCharge.grossAmount], dan masa berlaku tagihan
/// **selalu 15 menit** sejak dibuat sehingga dihitung di sisi aplikasi.
library;

/// Status transaksi mengikuti Midtrans.
enum PaymentTxStatus {
  /// Tagihan dibuat, menunggu pembayaran.
  pending('pending'),

  /// Pembayaran berhasil (`capture` untuk kartu kredit).
  settlement('settlement'),

  /// Lewat 15 menit, tidak dibayar.
  expire('expire'),

  /// Dibatalkan.
  cancel('cancel'),

  /// Ditolak / gagal.
  deny('deny'),
  failure('failure'),

  /// Nilai yang belum dikenal aplikasi.
  unknown('');

  const PaymentTxStatus(this.code);

  final String code;

  static PaymentTxStatus fromCode(Object? raw) {
    final code = raw?.toString().trim().toLowerCase();
    // `capture` adalah bentuk lunas untuk kartu kredit.
    if (code == 'capture') return settlement;
    for (final s in values) {
      if (s != unknown && s.code == code) return s;
    }
    return unknown;
  }

  bool get isPaid => this == settlement;

  bool get isPending => this == pending;

  /// Tagihan sudah tidak bisa dibayar lagi — pembeli perlu memesan ulang.
  bool get isDead =>
      this == expire || this == cancel || this == deny || this == failure;

  /// Label siap tampil.
  String get label => switch (this) {
    pending => 'Menunggu pembayaran',
    settlement => 'Pembayaran berhasil',
    expire => 'Tagihan kedaluwarsa',
    cancel => 'Pembayaran dibatalkan',
    deny => 'Pembayaran ditolak',
    failure => 'Pembayaran gagal',
    unknown => 'Status tidak diketahui',
  };
}

/// Hasil `POST /payment/api/v2/midtrans/charge`.
///
/// Field yang kosong tidak dikirim server, jadi ketersediaannya bergantung
/// pada [paymentType]:
/// - `qris`, `gopay` → [qrCode] (URL **gambar** QR, bukan muatan QRIS)
/// - `gopay` → [deeplinkUrl]
/// - `bank_transfer` → [bank] & [vaNumber]
/// - `echannel` → [billKey] & [billerCode]
/// - `credit_card` → [redirectUrl] (3DS)
/// - semua → [instructionHtml]
class PaymentCharge {
  const PaymentCharge({
    required this.orderId,
    required this.transactionId,
    required this.paymentType,
    required this.grossAmount,
    required this.status,
    this.bank = '',
    this.vaNumber = '',
    this.billKey = '',
    this.billerCode = '',
    this.qrCode = '',
    this.deeplinkUrl = '',
    this.redirectUrl = '',
    this.instructionHtml = '',
    this.snapToken = '',
    this.createdAt,
  });

  final String orderId;
  final String transactionId;

  /// `qris`, `gopay`, `bank_transfer`, `echannel`, atau `credit_card`.
  final String paymentType;

  /// Nominal yang dibayar pembeli.
  final int grossAmount;

  final PaymentTxStatus status;

  final String bank;
  final String vaNumber;
  final String billKey;
  final String billerCode;

  /// URL **gambar** QR — ditampilkan langsung, bukan digambar ulang.
  final String qrCode;

  final String deeplinkUrl;
  final String redirectUrl;

  /// Instruksi pembayaran siap tampil dari server (HTML).
  final String instructionHtml;

  /// Waktu tagihan dibuat di sisi aplikasi. Dipakai menghitung batas 15 menit
  /// karena server tidak mengirim `expires_at`.
  final DateTime? createdAt;

  /// Token Snap. Hanya diperlukan bila memakai Snap SDK; untuk webview
  /// diabaikan — [redirectUrl] sudah cukup.
  final String snapToken;

  bool get hasQr => qrCode.trim().isNotEmpty;
  bool get hasVa => vaNumber.trim().isNotEmpty;
  bool get hasBill => billKey.trim().isNotEmpty && billerCode.trim().isNotEmpty;
  bool get hasDeeplink => deeplinkUrl.trim().isNotEmpty;
  bool get hasRedirect => redirectUrl.trim().isNotEmpty;
  bool get hasInstruction => instructionHtml.trim().isNotEmpty;

  /// True bila tagihan ini dibuat lewat **Snap**, bukan Core API.
  ///
  /// Tandanya: satu-satunya sarana bayar yang dikirim adalah [redirectUrl].
  /// Nomor VA dan gambar QR-nya baru dibuat Midtrans setelah halaman Snap
  /// dibuka, jadi aplikasi tidak punya apa pun untuk digambar sendiri —
  /// yang bisa dilakukan hanya membuka halaman itu di dalam webview.
  bool get isSnap => hasRedirect && !hasQr && !hasVa && !hasBill;

  /// Batas waktu pembayaran: 15 menit sejak tagihan dibuat (aturan server,
  /// tidak bisa diatur dari request dan tidak dikirim di respons).
  DateTime? get expiresAt =>
      createdAt?.add(const Duration(minutes: 15));

  factory PaymentCharge.fromJson(
    Map<String, dynamic> json, {
    DateTime? createdAt,
  }) => PaymentCharge(
    orderId: (json['order_id'] ?? '').toString(),
    transactionId: (json['transaction_id'] ?? '').toString(),
    paymentType: (json['payment_type'] ?? '').toString(),
    grossAmount: _int(json['gross_amount']) ?? 0,
    status: PaymentTxStatus.fromCode(json['transaction_status']),
    bank: (json['bank'] ?? '').toString(),
    vaNumber: (json['va_number'] ?? '').toString(),
    billKey: (json['bill_key'] ?? '').toString(),
    billerCode: (json['biller_code'] ?? '').toString(),
    qrCode: (json['qr_code'] ?? '').toString(),
    deeplinkUrl: (json['deeplink_url'] ?? '').toString(),
    redirectUrl: (json['redirect_url'] ?? '').toString(),
    instructionHtml: (json['instruction_html'] ?? '').toString(),
    snapToken: (json['snap_token'] ?? '').toString(),
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// Hasil `GET /payment/api/v2/status/{order_id}`.
///
/// Status diperbarui server lewat webhook Midtrans, jadi aplikasi cukup
/// menanyakannya berkala — tidak perlu lagi menebak dari daftar pesanan.
class PaymentStatus {
  const PaymentStatus({
    required this.orderId,
    required this.status,
    this.provider = '',
    this.paymentType = '',
    this.grossAmount = 0,
    this.bank = '',
    this.vaNumber = '',
  });

  final String orderId;
  final PaymentTxStatus status;
  final String provider;
  final String paymentType;
  final int grossAmount;

  /// Dari `payment_instruction` — hanya terisi untuk transfer bank.
  final String bank;
  final String vaNumber;

  factory PaymentStatus.fromJson(Map<String, dynamic> json) {
    final instruction = (json['payment_instruction'] as Map?)
        ?.cast<String, dynamic>();
    return PaymentStatus(
      orderId: (json['order_id'] ?? '').toString(),
      status: PaymentTxStatus.fromCode(json['transaction_status']),
      provider: (json['provider'] ?? '').toString(),
      paymentType: (json['payment_type'] ?? '').toString(),
      grossAmount: _int(json['gross_amount']) ?? 0,
      bank: (instruction?['bank'] ?? '').toString(),
      vaNumber: (instruction?['va_number'] ?? '').toString(),
    );
  }
}

/// Hasil `POST /payment/api/v2/payment-methods/calculate`.
class PaymentCalculation {
  const PaymentCalculation({
    required this.value,
    required this.amount,
    required this.fee,
    required this.total,
    this.provider = '',
    this.addons = 0,
    this.percentage = 0,
    this.taxPercentage = 0,
    this.baseFee = 0,
    this.tax = 0,
  });

  final String value;
  final String provider;

  /// Nominal sebelum biaya admin.
  final int amount;

  final int addons;
  final double percentage;

  /// Pajak atas biaya layanan, dalam persen.
  final double taxPercentage;

  /// Biaya sebelum pajak.
  final int baseFee;

  /// Nilai pajak atas [baseFee].
  final double tax;

  /// Biaya admin hasil hitungan server — sudah termasuk pajak.
  final int fee;

  /// Nominal setelah biaya admin.
  final int total;

  factory PaymentCalculation.fromJson(Map<String, dynamic> json) =>
      PaymentCalculation(
        value: (json['value'] ?? '').toString(),
        provider: (json['provider'] ?? '').toString(),
        amount: _int(json['amount']) ?? 0,
        addons: _int(json['addons']) ?? 0,
        percentage: _double(json['percentage']) ?? 0,
        taxPercentage: _double(json['tax_percentage']) ?? 0,
        baseFee: _int(json['base_fee']) ?? 0,
        tax: _double(json['tax']) ?? 0,
        fee: _int(json['fee']) ?? 0,
        total: _int(json['total']) ?? 0,
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
