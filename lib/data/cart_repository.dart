import 'package:dio/dio.dart';

import '../core/config/env.dart';
import '../core/network/api_error.dart';
import '../core/network/dio_client.dart';
import 'api/cart_api.dart';
import 'models/cart.dart';

/// Mengambil & mengubah keranjang server, lalu memetakan respons `{message,
/// data}` ke [ServerCart]. Galat diterjemahkan menjadi [ApiException] berpesan
/// Bahasa Indonesia (kode server seperti `stok_tidak_tersedia` dipetakan ke
/// kalimat yang ramah).
class CartRepository {
  CartRepository(this._api);

  final CartApi _api;

  Future<ServerCart> fetch(int outletId) =>
      _run(() => _api.get(outletId));

  Future<ServerCart> add(
    int outletId, {
    required int menuId,
    required int quantity,
    List<Map<String, dynamic>>? props,
  }) =>
      _run(() => _api.add(
            outletId,
            menuId: menuId,
            quantity: quantity,
            props: props,
          ));

  Future<ServerCart> updateQty(
    int outletId,
    int cartId, {
    required int quantity,
    List<Map<String, dynamic>>? props,
  }) =>
      _run(() => _api.update(outletId, cartId, quantity: quantity, props: props));

  Future<ServerCart> remove(int outletId, int cartId) =>
      _run(() => _api.remove(outletId, cartId));

  /// Kosongkan keranjang. Server membalas `data: null` → keranjang kosong.
  Future<ServerCart> clear(int outletId) => _run(() => _api.clear(outletId));

  /// Cek stok sebelum bayar. `true` bila semua item tersedia.
  Future<bool> validate(int outletId) async {
    _ensureConfigured();
    try {
      final res = await _api.validate(outletId);
      final data = _dataOf(res.data);
      if (data is Map) {
        final v = data['available'];
        if (v is bool) return v;
        if (v is num) return v != 0;
      }
      if (res.data is Map && (res.data as Map)['available'] is bool) {
        return (res.data as Map)['available'] as bool;
      }
      return true;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // --- Inti ------------------------------------------------------------------

  Future<ServerCart> _run(Future<Response<dynamic>> Function() call) async {
    _ensureConfigured();
    try {
      final res = await call();
      return _parse(res.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Ambil isi keranjang dari body `{message, data}`. `data` null/kosong
  /// (mis. keranjang kadaluarsa) dianggap keranjang kosong — bukan galat.
  ServerCart _parse(Object? body) {
    final data = _dataOf(body);
    if (data is Map) {
      return ServerCart.fromJson(data.cast<String, dynamic>());
    }
    return ServerCart.empty();
  }

  Object? _dataOf(Object? body) {
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
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

    final raw = serverMessage(e);
    return ApiException(
      _friendly(raw) ?? raw ?? 'Gagal memproses keranjang. Coba lagi.',
      statusCode: status,
    );
  }

  /// Terjemahkan kode galat server ke kalimat ramah. Null bila tak dikenal.
  String? _friendly(String? code) {
    switch (code?.trim().toLowerCase()) {
      case 'stok_tidak_tersedia':
        return 'Stok tidak mencukupi untuk jumlah ini.';
      case 'menu_tidak_tersedia':
        return 'Menu ini sedang tidak tersedia.';
      case 'keranjang_kosong':
        return 'Keranjang masih kosong.';
      case 'outlet_not_found':
        return 'Outlet tidak ditemukan.';
      case 'cart_not_found':
        return 'Keranjang tidak ditemukan.';
      case 'data kosong':
        return 'Keranjang masih kosong.';
      default:
        return null;
    }
  }

  void _ensureConfigured() {
    if (Env.isConfigured) return;
    throw const ApiException(
      'Konfigurasi server belum lengkap. Isi BASE_URL & API_KEY pada file '
      '.env lalu jalankan ulang aplikasi.',
    );
  }
}

/// Instance global siap pakai.
final CartRepository cartRepository = CartRepository(CartApi(dio));
