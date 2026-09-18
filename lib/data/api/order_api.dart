import 'package:dio/dio.dart';

/// Endpoint checkout & pesanan (POS app). Kelas "tipis" — hanya memanggil Dio;
/// parsing & penerjemahan galat ada di `OrderRepository`.
///
/// Semua rute butuh token Bearer (bukan apikey). Checkout berada di bawah
/// outlet karena isinya diambil dari keranjang outlet tersebut, sedangkan
/// daftar/detail/pembatalan pesanan tidak terikat outlet.
class OrderApi {
  OrderApi(this._dio);

  final Dio _dio;

  /// `POST /pos/app/v1/outlets/:id/checkout` — ubah seluruh keranjang outlet
  /// ini menjadi satu pesanan `app_pending`.
  ///
  /// [pickupAt] dalam RFC3339 WITA (`2026-09-14T15:00:00+08:00`); null =
  /// server memakai 1 jam dari sekarang. [keterangan] maks 255 karakter.
  Future<Response<dynamic>> checkout(
    int outletId, {
    String? pickupAt,
    String? keterangan,
  }) {
    return _dio.post<dynamic>(
      '/pos/app/v1/outlets/$outletId/checkout',
      data: {
        if (pickupAt != null && pickupAt.isNotEmpty) 'pickup_at': pickupAt,
        if (keterangan != null && keterangan.isNotEmpty)
          'keterangan': keterangan,
      },
    );
  }

  /// `GET /pos/app/v1/orders` — daftar pesanan berhalaman.
  ///
  /// [status]: `active` (masih berjalan), `history` (selesai/batal), atau null
  /// untuk semua.
  Future<Response<dynamic>> list({
    String? status,
    int page = 1,
    int limit = 10,
  }) {
    return _dio.get<dynamic>(
      '/pos/app/v1/orders',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'limit': limit,
      },
    );
  }

  /// `GET /pos/app/v1/orders/:id` — detail satu pesanan.
  Future<Response<dynamic>> detail(int id) =>
      _dio.get<dynamic>('/pos/app/v1/orders/$id');

  /// `POST /pos/app/v1/orders/:id/cancel` — batalkan pesanan `app_pending`.
  Future<Response<dynamic>> cancel(int id) =>
      _dio.post<dynamic>('/pos/app/v1/orders/$id/cancel');
}
