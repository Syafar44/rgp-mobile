/// Hasil `POST /pos/app/v1/outlets/:id/checkout`.
///
/// **Bentuknya berbeda dari dokumen API Aplikasi Customer bagian 4.** Server
/// kini memakai alur bayar-dulu: checkout tidak langsung membuat pesanan POS,
/// melainkan sebuah tagihan berstatus `pending` ("Menunggu pembayaran").
/// Karena itu responsnya bukan detail pesanan:
///
/// - [orderId] berupa **string** (`APP1789701426894`), bukan id numerik;
///   `GET /orders/:id` belum bisa dipakai untuk tagihan ini.
/// - [posOrderId] masih null sampai pembayaran lunas — begitu terisi, pesanan
///   baru muncul di `GET /orders`.
/// - [chargePath] memberi tahu endpoint mana yang harus dipanggil untuk
///   membuat tagihan (mis. `/sumopod/charge`), relatif terhadap
///   `/payment/api/v2`.
/// - Tidak ada `total_amount`, `item_count`, maupun `lines`; yang tersedia
///   hanya [subtotalAmount].
library;

import '../api/payment_api.dart';

class CheckoutResult {
  const CheckoutResult({
    required this.orderId,
    required this.outletId,
    required this.status,
    required this.statusLabel,
    required this.subtotalAmount,
    this.paymentMethod = '',
    this.provider = '',
    this.chargePath = '',
    this.expiresAt,
    this.pickupAt,
    this.posOrderId,
    this.createdAt,
  });

  /// Nomor pesanan (dipakai sebagai `order_id` saat membuat tagihan).
  final String orderId;

  final int outletId;

  /// Status mentah, mis. `pending`.
  final String status;

  /// Label siap tampil, mis. "Menunggu pembayaran".
  final String statusLabel;

  /// Nilai pesanan sebelum biaya admin.
  final int subtotalAmount;

  /// `value` metode pembayaran yang dipilih, mis. `qris`.
  final String paymentMethod;

  /// Penyedia pembayaran, mis. `sumopod`.
  final String provider;

  /// Path endpoint charge, relatif terhadap `/payment/api/v2`.
  final String chargePath;

  /// Batas waktu pembayaran (waktu asli dari server).
  final DateTime? expiresAt;

  /// Rencana ambil.
  final DateTime? pickupAt;

  /// Id pesanan POS. Null selama belum dibayar.
  final int? posOrderId;

  final DateTime? createdAt;

  /// True bila pembayaran belum lunas (pesanan POS belum terbentuk).
  bool get isAwaitingPayment => posOrderId == null;

  /// True bila tagihan untuk pesanan ini bisa dibuat.
  ///
  /// Biasanya butuh `charge_path` dari server. Selama [PaymentApi.paksaSnap]
  /// menyala, path-nya sudah ditentukan aplikasi sehingga yang tersisa hanya
  /// syarat nomor pesanan.
  bool get canCharge =>
      orderId.isNotEmpty &&
      (PaymentApi.paksaSnap || chargePath.trim().isNotEmpty);

  factory CheckoutResult.fromJson(Map<String, dynamic> json) => CheckoutResult(
    orderId: (json['order_id'] ?? json['document_number'] ?? '').toString(),
    outletId: _int(json['outlet_id']) ?? 0,
    status: (json['status'] ?? '').toString(),
    statusLabel: (json['status_label'] ?? '').toString(),
    subtotalAmount:
        _int(json['subtotal_amount']) ?? _int(json['total_amount']) ?? 0,
    paymentMethod: (json['payment_method'] ?? '').toString(),
    provider: (json['provider'] ?? '').toString(),
    chargePath: (json['charge_path'] ?? '').toString(),
    expiresAt: _dateTime(json['expires_at']),
    pickupAt: _dateTime(json['pickup_at']),
    posOrderId: _int(json['pos_orders_id']),
    createdAt: _dateTime(json['created_at']),
  );
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

DateTime? _dateTime(Object? v) {
  if (v is String && v.trim().isNotEmpty) return DateTime.tryParse(v.trim());
  return null;
}
