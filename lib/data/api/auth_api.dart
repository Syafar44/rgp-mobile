import 'package:dio/dio.dart';

/// Endpoint autentikasi & pendaftaran (lihat `API_REGISTER_FLUTTER.md`).
///
/// Kelas ini sengaja "tipis": hanya memanggil Dio dan mengembalikan [Response]
/// apa adanya. Parsing & penerjemahan galat ditangani `AuthRepository`.
/// Pola mengikuti `svp_app/lib/features/auth/data/auth_api.dart`.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// `POST /register` — daftar customer end user baru. Publik, tanpa token.
  /// Balasan `201` TIDAK berisi token; panggil [auth] setelahnya.
  Future<Response<dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String contact,
    required String address,
  }) {
    return _dio.post<dynamic>(
      '/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'contact': contact,
        'address': address,
      },
    );
  }

  /// `POST /auth` — login. Butuh header `apikey` (disisipkan `createDio`).
  Future<Response<dynamic>> auth({
    required String email,
    required String password,
  }) {
    return _dio.post<dynamic>(
      '/auth',
      data: {'email': email, 'password': password},
    );
  }

  /// `POST /verify_email` — periksa kode OTP 6 digit. Publik.
  Future<Response<dynamic>> verifyEmail({
    required String email,
    required String code,
  }) {
    return _dio.post<dynamic>(
      '/verify_email',
      data: {'email': email, 'code': code},
    );
  }

  /// `POST /resend_verify` — kirim ulang kode. Publik.
  ///
  /// Balasannya SELALU sama, terdaftar maupun tidak — jangan dipakai untuk
  /// mengecek apakah sebuah email sudah punya akun.
  Future<Response<dynamic>> resendVerify({required String email}) {
    return _dio.post<dynamic>('/resend_verify', data: {'email': email});
  }

  /// `GET /me` — data dari klaim token JWT yang sedang dipakai.
  ///
  /// Catatan: `/me` membaca klaim token, bukan database. Bila token belum
  /// diperbarui setelah verifikasi, `email_verified` di sini tetap `false`.
  Future<Response<dynamic>> me() => _dio.get<dynamic>('/me');
}
