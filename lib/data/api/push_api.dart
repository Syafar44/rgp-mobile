import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';

/// Endpoint identitas push (POS app). Kelas "tipis" — parsing & penerjemahan
/// galat ada di `PushRepository`.
class PushApi {
  PushApi(this._dio);

  final Dio _dio;

  /// `GET /pos/app/v1/push_identity` — ambil `external_id` pembeli.
  ///
  /// Nilainya dibuat server dari akun pada token (bukan `users_id`) dan bisa
  /// berubah bila kunci di server diganti, jadi selalu diambil dari sini —
  /// tidak pernah disimpan lokal lalu dipakai ulang.
  ///
  /// **Hanya token Bearer.** Rute ini tidak memakai header `apikey` (dikonfirmasi
  /// tim backend), jadi penyisipannya dimatikan lewat [noApiKey] — berbeda dari
  /// endpoint POS lain di aplikasi ini.
  Future<Response<dynamic>> identity() =>
      _dio.get<dynamic>('/pos/app/v1/push_identity', options: noApiKey());
}
