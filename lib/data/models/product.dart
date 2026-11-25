/// Satu item menu / produk roti (`GET /pos/app/v1/outlets/:id/menus`).
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.description,
    this.emoji = '🥐',
    this.available = true,
    this.promoPrice,
    this.isNew = false,
    this.badge,
    this.imageUrl,
    this.code = '',
    this.categoryId,
    this.menuType = 'regular',
    this.maxQty = 0,
    this.variants = const [],
  });

  final String id;
  final String name;

  /// Kategori: mis. "Roti Gembung", "Minuman", "Makanan", "Paket".
  final String category;

  /// Kode menu dari server, mis. `RM-001`.
  final String code;

  /// Id kategori — dipakai untuk menyaring menu yang tidak layak dipesan
  /// online (server sengaja mengirim seluruh menu outlet).
  final int? categoryId;

  /// `regular` atau `package`.
  final String menuType;

  /// Hanya untuk paket: total varian yang harus dipilih per satu paket.
  final int maxQty;

  /// Hanya untuk paket: pilihan varian yang tersedia.
  final List<MenuVariant> variants;

  /// True bila menu ini paket — penambahan ke keranjang wajib menyertakan
  /// `props` sebanyak [maxQty] varian.
  bool get isPackage => menuType.toLowerCase() == 'package';

  /// Harga normal dalam Rupiah (tanpa desimal).
  final int price;
  final String description;

  /// Emoji sebagai placeholder gambar sementara masih dummy.
  final String emoji;
  final bool available;

  /// Harga promo (jika ada). Bila terisi, [price] tampil dicoret.
  final int? promoPrice;

  /// Tandai produk baru (badge "Baru").
  final bool isNew;

  /// Label badge kustom, mis. "Promo Delivery".
  final String? badge;

  /// URL foto produk (dummy dari sumber gambar gratis). Bila null, tampil
  /// [emoji] sebagai placeholder.
  final String? imageUrl;

  /// True bila produk sedang promo.
  bool get isPromo => promoPrice != null;

  /// Harga yang berlaku sekarang (promo bila ada).
  int get effectivePrice => promoPrice ?? price;

  /// Membentuk [Product] dari JSON (dipakai saat integrasi API nanti).
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🥐',
      available: json['available'] as bool? ?? true,
      promoPrice: (json['promoPrice'] as num?)?.toInt(),
      isNew: json['isNew'] as bool? ?? false,
      badge: json['badge'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'categoryId': categoryId,
        'menuType': menuType,
        'maxQty': maxQty,
        'name': name,
        'category': category,
        'price': price,
        'description': description,
        'emoji': emoji,
        'available': available,
        'promoPrice': promoPrice,
        'isNew': isNew,
        'badge': badge,
        'imageUrl': imageUrl,
      };
}

/// Satu pilihan varian di dalam sebuah paket (`props` pada endpoint menu).
class MenuVariant {
  const MenuVariant({
    required this.id,
    required this.title,
    this.code = '',
  });

  /// `menu_id` yang dikirim saat menambah paket ke keranjang.
  final int id;

  final String title;
  final String code;

  factory MenuVariant.fromJson(Map<String, dynamic> json) => MenuVariant(
        id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
        title: (json['title'] ?? json['name'] ?? '').toString(),
        code: (json['code'] ?? '').toString(),
      );
}
