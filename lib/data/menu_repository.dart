import 'package:dio/dio.dart';

import '../core/config/env.dart';
import '../core/network/api_error.dart';
import '../core/network/dio_client.dart';
import 'api/menu_api.dart';
import 'models/product.dart';

/// Mengambil menu sebuah outlet dari API dan memetakannya ke [Product].
///
/// **Pemetaan field masih perkiraan** (respons `/outlets/:id/menus` belum
/// terdokumentasi). Parser di bawah sengaja toleran: mencoba beberapa nama
/// field yang lazim (snake_case + variasi Indonesia) dan mendukung dua bentuk
/// respons: daftar item rata, atau dikelompokkan per kategori. Setelah bentuk
/// respons asli diketahui, cukup rapikan daftar kunci di [_product].
class MenuRepository {
  MenuRepository(this._api);

  final MenuApi _api;

  Future<List<Product>> outletMenus(int outletId) async {
    _ensureConfigured();
    try {
      final res = await _api.outletMenus(outletId);
      return _parse(res.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // --- Parsing ---------------------------------------------------------------

  List<Product> _parse(Object? body) {
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
        for (final it in sub) {
          if (it is Map) {
            products.add(
              _product(it.cast<String, dynamic>(), fallbackCategory: cat),
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

  Product _product(Map<String, dynamic> j, {String? fallbackCategory}) {
    final price =
        _num(j, ['price', 'sell_price', 'sale_price', 'harga', 'base_price'])
            ?.toInt() ??
        0;
    final promo = _num(j, ['promo_price', 'discount_price', 'harga_promo']);
    return Product(
      id: (j['id'] ?? j['menu_id'] ?? j['product_id'] ?? '').toString(),
      name: _str(j, ['title', 'name', 'menu_name', 'product_name', 'nama']) ??
          '',
      category:
          _str(j, ['category', 'category_name', 'kategori', 'category_label']) ??
          fallbackCategory ??
          'Menu',
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
