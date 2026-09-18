import 'package:dio/dio.dart';

/// Endpoint menu outlet (POS app). Kelas "tipis" — hanya memanggil Dio.
class MenuApi {
  MenuApi(this._dio);

  final Dio _dio;

  /// `GET /pos/app/v1/outlets/:id/menus` — daftar menu untuk sebuah outlet.
  Future<Response<dynamic>> outletMenus(int outletId) {
    return _dio.get<dynamic>('/pos/app/v1/outlets/$outletId/menus');
  }
}
