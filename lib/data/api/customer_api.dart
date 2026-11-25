import 'package:dio/dio.dart';

/// Endpoint profil customer end user (grup `/customer`).
///
/// Memakai token Bearer yang sama dengan endpoint lain. Data kontak & alamat
/// sengaja dipisahkan dari `GET /me` — `/me` hanya membaca klaim token.
class CustomerApi {
  CustomerApi(this._dio);

  final Dio _dio;

  /// `GET /customer/me` — profil customer milik user yang sedang login.
  /// Customer ditentukan dari `userid` di dalam token, tanpa parameter.
  Future<Response<dynamic>> me() => _dio.get<dynamic>('/customer/me');

  /// `PATCH /customer/profile` — ubah profil.
  ///
  /// Ketiganya wajib dikirim, termasuk yang tidak berubah. `email` tidak bisa
  /// diubah lewat endpoint ini karena terikat proses verifikasi.
  Future<Response<dynamic>> updateProfile({
    required String name,
    required String contact,
    required String address,
  }) {
    return _dio.patch<dynamic>(
      '/customer/profile',
      data: {'name': name, 'contact': contact, 'address': address},
    );
  }

  /// `PATCH /customer/password` — ganti kata sandi.
  ///
  /// Token yang sedang dipakai tetap berlaku setelah berhasil; server tidak
  /// mencabut sesi.
  Future<Response<dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return _dio.patch<dynamic>(
      '/customer/password',
      data: {'old_password': oldPassword, 'new_password': newPassword},
    );
  }

  /// Path penghapusan akun — dikonfirmasi tim backend: `/account`, bukan
  /// di bawah `/customer` seperti endpoint profil lainnya.
  static const String deleteAccountPath = '/account';

  /// `DELETE /account` — hapus akun beserta datanya, permanen.
  ///
  /// **Body wajib.** Tanpa `password`, server menjawab `400
  /// invalid_confirmation` dan akun tidak dihapus.
  ///
  /// `Content-Type: application/json` disetel **eksplisit**. Sebagian klien
  /// HTTP tidak menyertakan header itu pada DELETE walau body-nya ada, dan
  /// tanpa header tersebut server tidak membaca body-nya — hasilnya `400`
  /// yang menyesatkan. Dio memang biasanya menyetelnya sendiri untuk body
  /// berupa Map; ditulis di sini supaya tidak bergantung pada perilaku
  /// bawaan yang bisa berubah.
  ///
  /// [password] dipakai karena pembeli aplikasi ini masuk dengan email &
  /// kata sandi. Brief menyebut dua metode lain untuk masa depan — `otp`
  /// untuk masuk via nomor HP, dan `confirmation: "HAPUS"` untuk Google
  /// Sign-In — keduanya belum berlaku di sini.
  Future<Response<dynamic>> deleteAccount({required String password}) {
    return _dio.delete<dynamic>(
      deleteAccountPath,
      data: {'password': password},
      options: Options(contentType: Headers.jsonContentType),
    );
  }
}
