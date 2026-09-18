import 'package:dio/dio.dart';

/// Endpoint keranjang server (POS app). Kelas "tipis" — hanya memanggil Dio dan
/// mengembalikan [Response] apa adanya; parsing/penerjemahan galat ada di
/// `CartRepository`.
///
/// Semua rute keranjang berada di bawah `/pos/app/v1/outlets/:id/cart` dan
/// membutuhkan token Bearer (bukan apikey).
class CartApi {
  CartApi(this._dio);

  final Dio _dio;

  String _base(int outletId) => '/pos/app/v1/outlets/$outletId/cart';

  /// `GET .../cart` — lihat keranjang outlet ini.
  Future<Response<dynamic>> get(int outletId) {
    return _dio.get<dynamic>(_base(outletId));
  }

  /// `POST .../cart` — tambah menu. Menu + komposisi sama → quantity digabung.
  Future<Response<dynamic>> add(
    int outletId, {
    required int menuId,
    required int quantity,
    List<Map<String, dynamic>>? props,
  }) {
    return _dio.post<dynamic>(
      _base(outletId),
      data: {
        'menu_id': menuId,
        'quantity': quantity,
        if (props != null) 'props': props,
      },
    );
  }

  /// `PATCH .../cart/:cartId` — ubah quantity satu baris (quantity > 0).
  Future<Response<dynamic>> update(
    int outletId,
    int cartId, {
    required int quantity,
    List<Map<String, dynamic>>? props,
  }) {
    return _dio.patch<dynamic>(
      '${_base(outletId)}/$cartId',
      data: {
        'quantity': quantity,
        if (props != null) 'props': props,
      },
    );
  }

  /// `DELETE .../cart/:cartId` — hapus satu baris.
  Future<Response<dynamic>> remove(int outletId, int cartId) {
    return _dio.delete<dynamic>('${_base(outletId)}/$cartId');
  }

  /// `DELETE .../cart` — kosongkan seluruh keranjang.
  Future<Response<dynamic>> clear(int outletId) {
    return _dio.delete<dynamic>(_base(outletId));
  }

  /// `POST .../cart/validate` — cek ketersediaan stok sebelum bayar.
  Future<Response<dynamic>> validate(int outletId) {
    return _dio.post<dynamic>('${_base(outletId)}/validate');
  }
}
