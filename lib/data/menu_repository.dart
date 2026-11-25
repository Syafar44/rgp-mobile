import 'package:dio/dio.dart';

import '../core/config/env.dart';
import '../core/network/api_error.dart';
import '../core/network/dio_client.dart';
import 'api/menu_api.dart';
import 'models/product.dart';

/// Mengambil menu sebuah outlet dari API dan memetakannya ke [Product].
///
/// Bentuk respons resmi (dokumen API Aplikasi Customer bagian 2) adalah daftar
/// kategori — `{category_id, category, data: [menu...]}` — dengan tiap menu
/// membawa `id`, `code`, `title`, `menu_type`, `price`, `image_url`, plus
/// `max_qty` & `props` khusus paket. Parser tetap toleran terhadap nama field
/// lain agar aman bila server menambah variasi.
///
/// Catatan dari dokumen: server mengirim **seluruh** menu outlet dan tidak
/// menyaring mana yang layak dipesan online — penyaringan lewat
/// [excludeCategoryIds] adalah tanggung jawab aplikasi.
class MenuRepository {
  MenuRepository(this._api);

  final MenuApi _api;

  /// Ambil menu outlet.
  ///
  /// [excludeCategoryIds] membuang kategori yang tidak layak dipesan online
  /// (mis. es krim). Kosong = tampilkan semua, yang tepat untuk pickup.
  Future<List<Product>> outletMenus(
    int outletId, {
    Set<int> excludeCategoryIds = const {},
  }) async {
    _ensureConfigured();
    try {
      final res = await _api.outletMenus(outletId);
      final all = parseMenus(res.data);
      if (excludeCategoryIds.isEmpty) return all;
      return all
          .where((p) => !excludeCategoryIds.contains(p.categoryId))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // --- Parsing ---------------------------------------------------------------

  /// Petakan body respons menu menjadi daftar [Product].
  ///
  /// Dipublikasikan agar bentuk respons resmi bisa diuji tanpa jaringan.
  List<Product> parseMenus(Object? body) {
    final products = <Product>[];
    for (final e in _extractList(body)) {
      if (e is! Map) continue;
      final m = e.cast<String, dynamic>();
      // Bentuk dikelompokkan per kategori: {category, data: [...]} — server
      // memakai `data` untuk daftar item di dalam grup.
      final sub = m['data'] ?? m['items'] ?? m['menus'] ?? m['products'];
      if (sub is List) {
        final cat =
            _str(m, ['category', 'category_name', 'name', 'kategori']) ?? 'Menu';
        final catId = _num(m, ['category_id', 'categoryId'])?.toInt();
        for (final it in sub) {
          if (it is Map) {
            products.add(
              _product(
                it.cast<String, dynamic>(),
                fallbackCategory: cat,
                fallbackCategoryId: catId,
              ),
            );
          }
        }
      } else {
        products.add(_product(m));
      }
    }
    return products;
  }

  /// Ambil daftar item dari berbagai kemungkinan pembungkus respons.
  List<dynamic> _extractList(Object? body) {
    if (body is List) return body;
    if (body is Map) {
      final data = body['data'] ?? body['menus'] ?? body['items'];
      if (data is List) return data;
      if (data is Map) {
        final inner = data['items'] ?? data['menus'] ?? data['data'];
        if (inner is List) return inner;
      }
    }
    return const [];
  }

  Product _product(
    Map<String, dynamic> j, {
    String? fallbackCategory,
    int? fallbackCategoryId,
  }) {
    final price =
        _num(j, ['price', 'sell_price', 'sale_price', 'harga', 'base_price'])
            ?.toInt() ??
        0;
    final promo = _num(j, ['promo_price', 'discount_price', 'harga_promo']);
    // `props` hanya ada untuk menu paket: daftar varian yang bisa dipilih.
    final rawProps = j['props'];
    return Product(
      id: (j['id'] ?? j['menu_id'] ?? j['product_id'] ?? '').toString(),
      name: _str(j, ['title', 'name', 'menu_name', 'product_name', 'nama']) ??
          '',
      code: _str(j, ['code', 'menu_code']) ?? '',
      category:
          _str(j, ['category', 'category_name', 'kategori', 'category_label']) ??
          fallbackCategory ??
          'Menu',
      categoryId:
          _num(j, ['category_id', 'categoryId'])?.toInt() ?? fallbackCategoryId,
      menuType: _str(j, ['menu_type', 'menuType', 'type']) ?? 'regular',
      maxQty: _num(j, ['max_qty', 'maxQty'])?.toInt() ?? 0,
      variants: rawProps is List
          ? rawProps
                .whereType<Map>()
                .map((e) => MenuVariant.fromJson(e.cast<String, dynamic>()))
                .toList(growable: false)
          : const [],
      price: price,
      promoPrice: (promo != null && promo > 0 && promo < price)
          ? promo.toInt()
          : null,
      description: _str(j, ['description', 'desc', 'deskripsi']) ?? '',
      imageUrl: _str(j, [
        'image',
        'image_url',
        'photo',
        'thumbnail',
        'picture',
        'img',
        'image_path',
      ]),
      available: _bool(j, [
        'available',
        'is_available',
        'is_active',
        'active',
      ], def: true),
    );
  }

  // --- Galat -----------------------------------------------------------------

  ApiException _mapError(DioException e) {
    final network = networkErrorMessage(e);
    if (network != null) return ApiException(network);

    final status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      return ApiException(
        'Sesi Anda sudah berakhir. Silakan masuk lagi.',
        statusCode: status,
      );
    }
    return ApiException(
      serverMessage(e) ?? 'Gagal memuat menu. Coba lagi.',
      statusCode: status,
    );
  }

  void _ensureConfigured() {
    if (Env.isConfigured) return;
    throw const ApiException(
      'Konfigurasi server belum lengkap. Isi BASE_URL & API_KEY pada file '
      '.env lalu jalankan ulang aplikasi.',
    );
  }
}

// =============================================================================
// PEMBACA FIELD TOLERAN
// =============================================================================

num? _num(Map<String, dynamic> j, List<String> keys) {
  for (final k in keys) {
    final v = j[k];
    if (v is num) return v;
    if (v is String) {
      final p = num.tryParse(v);
      if (p != null) return p;
    }
  }
  return null;
}

String? _str(Map<String, dynamic> j, List<String> keys) {
  for (final k in keys) {
    final v = j[k];
    if (v != null) {
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
  }
  return null;
}

bool _bool(Map<String, dynamic> j, List<String> keys, {required bool def}) {
  for (final k in keys) {
    final v = j[k];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final l = v.trim().toLowerCase();
      if (['true', '1', 'yes', 'ya'].contains(l)) return true;
      if (['false', '0', 'no', 'tidak'].contains(l)) return false;
    }
  }
  return def;
}

/// Instance global siap pakai.
final MenuRepository menuRepository = MenuRepository(MenuApi(dio));
