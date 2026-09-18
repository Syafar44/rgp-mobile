import 'package:dio/dio.dart';

/// Endpoint outlet (POS app). Kelas "tipis" — hanya memanggil Dio dan
/// mengembalikan [Response] apa adanya; parsing/penerjemahan galat di
/// `OutletRepository`.
class OutletApi {
  OutletApi(this._dio);

  final Dio _dio;

  /// `POST /pos/app/v1/outlets/nearby` — daftar outlet terdekat dari lat/long.
  Future<Response<dynamic>> nearby({
    required double lat,
    required double long,
    int limit = 10,
  }) {
    return _dio.post<dynamic>(
      '/pos/app/v1/outlets/nearby',
      data: {'lat': lat, 'long': long, 'limit': limit},
    );
  }
}
