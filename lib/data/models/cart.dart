/// Model keranjang **sisi server** (`/pos/app/v1/outlets/:id/cart`).
///
/// Berbeda dari keranjang lokal lama: sumber kebenarannya ada di server —
/// setiap operasi (tambah/ubah/hapus) mengembalikan keranjang terbaru, jadi
/// aplikasi tinggal mengganti isi [CartStore] dengan hasil respons.
library;

/// Satu keranjang milik pembeli pada satu outlet.
class ServerCart {
  const ServerCart({
    this.outletId,
    this.items = const [],
    this.total = 0,
  });

  /// Outlet pemilik keranjang. Null bila keranjang kosong/baru.
  final int? outletId;

  final List<ServerCartItem> items;

  /// Total seluruh baris (Rupiah), dari server.
  final int total;

  bool get isEmpty => items.isEmpty;

  /// Total unit (jumlah semua quantity) — untuk badge/bilah keranjang.
  int get count => items.fold(0, (sum, e) => sum + e.quantity);

  factory ServerCart.empty() => const ServerCart();

  factory ServerCart.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return ServerCart(
      outletId: _int(json['outlet_id']),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => ServerCartItem.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      total: _int(json['total']) ?? 0,
    );
  }
}

/// Satu baris keranjang. [id] adalah **id baris keranjang** (dipakai untuk
/// PATCH/DELETE), berbeda dari [menuId].
class ServerCartItem {
  const ServerCartItem({
    required this.id,
    required this.menuId,
    required this.title,
    required this.menuType,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.imageUrl,
    this.props = const [],
    this.expiresAt,
  });

  final int id;
  final int menuId;
  final String title;

  /// `single` atau `package`.
  final String menuType;

  final int quantity;

  /// Harga satuan pada outlet ini (Rupiah).
  final int price;

  /// Subtotal baris (dari server).
  final int subtotal;

  final String? imageUrl;

  /// Isi paket (untuk `menu_type == package`).
  final List<CartProp> props;

  /// Kapan baris ini kedaluwarsa (keranjang server berumur ~30 menit).
  final DateTime? expiresAt;

  bool get isPackage => menuType.toLowerCase() == 'package';

  factory ServerCartItem.fromJson(Map<String, dynamic> json) {
    final rawProps = json['props'];
    return ServerCartItem(
      id: _int(json['id']) ?? 0,
      menuId: _int(json['menu_id']) ?? 0,
      title: (json['title'] ?? json['name'] ?? '').toString(),
      menuType: (json['menu_type'] ?? 'single').toString(),
      quantity: _int(json['quantity']) ?? 1,
      price: _int(json['price']) ?? 0,
      subtotal: _int(json['subtotal']) ?? 0,
      imageUrl: _str(json['image_url'] ?? json['image']),
      props: rawProps is List
          ? rawProps
              .whereType<Map>()
              .map((e) => CartProp.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      expiresAt: _dateTime(json['expires_at']),
    );
  }
}

/// Komponen di dalam sebuah paket keranjang.
class CartProp {
  const CartProp({
    required this.menuId,
    required this.title,
    required this.quantity,
  });

  final int menuId;
  final String title;
  final int quantity;

  factory CartProp.fromJson(Map<String, dynamic> json) => CartProp(
        menuId: _int(json['menu_id']) ?? 0,
        title: (json['title'] ?? '').toString(),
        quantity: _int(json['quantity']) ?? 1,
      );
}

// --- Pembaca nilai toleran -----------------------------------------------------

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}

String? _str(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

DateTime? _dateTime(Object? v) {
  if (v is String && v.trim().isNotEmpty) return DateTime.tryParse(v);
  return null;
}
