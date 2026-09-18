/// Pesanan aplikasi customer (`/pos/app/v1/orders`).
///
/// Bentuknya sama untuk hasil checkout, detail pesanan, dan pembatalan; daftar
/// pesanan memakai bentuk ringkas tanpa rincian item.
library;

import '../../core/utils/wita.dart';

/// Status pesanan. Untuk **tampilan** pakai [Order.statusLabel] dari server;
/// enum ini untuk **logika** (mis. tombol Batalkan hanya saat `app_pending`).
enum OrderStatus {
  /// Sudah checkout, belum diambil/dibayar di outlet.
  appPending('app_pending'),

  /// Sudah diambil & dibayar di outlet (kasir serah terima).
  active('active'),

  /// Dibatalkan pembeli atau kasir.
  appCancelled('app_cancelled'),

  /// Dibatalkan lewat mekanisme POS.
  voided('voided'),

  /// Status baru yang belum dikenal aplikasi — diperlakukan sebagai selesai.
  unknown('');

  const OrderStatus(this.code);

  final String code;

  static OrderStatus fromCode(Object? raw) {
    final code = raw?.toString().trim().toLowerCase();
    for (final s in values) {
      if (s != unknown && s.code == code) return s;
    }
    return unknown;
  }

  /// Masih berjalan → tampil di tab Pesanan.
  bool get isActive => this == appPending;

  /// Sudah tuntas/batal → tampil di tab Riwayat.
  bool get isDone => !isActive;

  bool get isCancelled => this == appCancelled || this == voided;

  /// Hanya pesanan `app_pending` yang boleh dibatalkan pembeli.
  bool get canCancel => this == appPending;
}

/// Sebuah pesanan.
class Order {
  const Order({
    required this.id,
    required this.documentNumber,
    required this.outletId,
    required this.outletName,
    required this.status,
    required this.statusLabel,
    required this.totalAmount,
    required this.itemCount,
    this.pickupAt,
    this.createdAt,
    this.keterangan = '',
    this.subtotalAmount = 0,
    this.discountAmount = 0,
    this.lines = const [],
  });

  final int id;

  /// Nomor yang disebutkan pembeli ke kasir saat mengambil pesanan.
  final String documentNumber;

  final int outletId;
  final String outletName;
  final OrderStatus status;

  /// Label status siap tampil dari server (mis. "Menunggu diambil").
  final String statusLabel;

  final int totalAmount;
  final int itemCount;

  /// Rencana ambil — jam dinding WITA (lihat `core/utils/wita.dart`).
  final DateTime? pickupAt;

  /// Waktu pesanan dibuat — jam dinding WITA.
  final DateTime? createdAt;

  final String keterangan;
  final int subtotalAmount;
  final int discountAmount;

  /// Rincian item. Kosong pada respons daftar pesanan.
  final List<OrderLine> lines;

  /// True bila respons ini membawa rincian item (detail, bukan daftar).
  bool get hasLines => lines.isNotEmpty;

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    return Order(
      id: _int(json['id']) ?? 0,
      documentNumber: (json['document_number'] ?? '').toString(),
      outletId: _int(json['outlet_id']) ?? 0,
      outletName: (json['outlet_name'] ?? '').toString(),
      status: OrderStatus.fromCode(json['status']),
      statusLabel: (json['status_label'] ?? '').toString(),
      totalAmount: _int(json['total_amount']) ?? 0,
      itemCount: _int(json['item_count']) ?? 0,
      pickupAt: parseWita(json['pickup_at']),
      createdAt: parseWita(json['created_at']),
      keterangan: (json['keterangan'] ?? '').toString(),
      subtotalAmount: _int(json['subtotal_amount']) ?? 0,
      discountAmount: _int(json['discount_amount']) ?? 0,
      lines: rawLines is List
          ? rawLines
                .whereType<Map>()
                .map((e) => OrderLine.fromJson(e.cast<String, dynamic>()))
                .toList(growable: false)
          : const [],
    );
  }
}

/// Satu baris item pesanan.
class OrderLine {
  const OrderLine({
    required this.menuId,
    required this.title,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.props = const [],
  });

  final int menuId;
  final String title;
  final int quantity;
  final int price;
  final int subtotal;

  /// Isi paket. `quantity` di sini sudah dikali jumlah paket.
  final List<OrderProp> props;

  bool get isPackage => props.isNotEmpty;

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    final rawProps = json['props'];
    return OrderLine(
      menuId: _int(json['menu_id']) ?? 0,
      title: (json['title'] ?? '').toString(),
      quantity: _int(json['quantity']) ?? 0,
      price: _int(json['price']) ?? 0,
      subtotal: _int(json['subtotal']) ?? 0,
      props: rawProps is List
          ? rawProps
                .whereType<Map>()
                .map((e) => OrderProp.fromJson(e.cast<String, dynamic>()))
                .toList(growable: false)
          : const [],
    );
  }
}

/// Komponen di dalam sebuah paket pesanan.
class OrderProp {
  const OrderProp({
    required this.menuId,
    required this.title,
    required this.quantity,
  });

  final int menuId;
  final String title;
  final int quantity;

  factory OrderProp.fromJson(Map<String, dynamic> json) => OrderProp(
    menuId: _int(json['menu_id']) ?? 0,
    title: (json['title'] ?? '').toString(),
    quantity: _int(json['quantity']) ?? 0,
  );
}

/// Sehalaman daftar pesanan beserta `metadata` paginasinya.
class OrderPage {
  const OrderPage({
    required this.orders,
    required this.page,
    required this.totalPage,
  });

  final List<Order> orders;
  final int page;
  final int totalPage;

  /// True bila masih ada halaman berikutnya.
  bool get hasMore => page < totalPage;

  factory OrderPage.fromResponse(Map<String, dynamic> body) {
    final data = body['data'];
    final meta = (body['metadata'] as Map?)?.cast<String, dynamic>();
    return OrderPage(
      orders: data is List
          ? data
                .whereType<Map>()
                .map((e) => Order.fromJson(e.cast<String, dynamic>()))
                .toList(growable: false)
          : const [],
      page: _int(meta?['page']) ?? 1,
      totalPage: _int(meta?['total_page']) ?? 1,
    );
  }
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}
