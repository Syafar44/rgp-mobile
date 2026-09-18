/// Hasil `POST /register` (`201 Created`).
///
/// Respons ini TIDAK berisi token login — setelah daftar, aplikasi tetap harus
/// memanggil `POST /auth` untuk mendapat token.
class RegisterResult {
  const RegisterResult({
    required this.id,
    required this.name,
    required this.email,
    required this.code,
  });

  /// Id user yang baru dibuat.
  final int id;

  final String name;
  final String email;

  /// Kode customer, mis. `CUS1789012345678`. Bukan kode OTP verifikasi email.
  final String code;

  /// Bentuk respons: `{"message": "Success", "data": { ... }}`.
  factory RegisterResult.fromResponse(Map<String, dynamic> body) {
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return RegisterResult(
      id: int.tryParse(data['id']?.toString() ?? '') ?? 0,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      code: data['code'] as String? ?? '',
    );
  }
}
