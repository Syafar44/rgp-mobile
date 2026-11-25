import 'package:dio/dio.dart';

import '../core/config/env.dart';
import '../core/network/api_error.dart';
import '../core/network/dio_client.dart';
import 'api/auth_api.dart';
import 'models/auth_session.dart';
import 'models/register_result.dart';
import 'models/user_profile.dart';

/// Alur pendaftaran, verifikasi email, dan lupa kata sandi (lihat
/// `API_REGISTER_FLUTTER.md` & `API-Lupa-Password-Flutter.md`).
///
/// Semua galat Dio diterjemahkan menjadi [ApiException] berisi pesan bahasa
/// Indonesia yang siap ditampilkan, jadi halaman UI tidak perlu tahu soal
/// kode HTTP. Pola berlapis (api → repository → UI) mengikuti svp_app.
class AuthRepository {
  AuthRepository(this._api);

  final AuthApi _api;

  // ---------------------------------------------------------------------------
  // ENDPOINT SATUAN
  // ---------------------------------------------------------------------------

  /// Langkah 1: `POST /register`. Respons tidak berisi token.
  Future<RegisterResult> register({
    required String name,
    required String email,
    required String password,
    required String contact,
    required String address,
  }) async {
    _ensureConfigured();
    try {
      final response = await _api.register(
        name: name.trim(),
        email: _normalizeEmail(email),
        password: password,
        contact: contact.trim(),
        address: address.trim(),
      );
      return RegisterResult.fromResponse(_asBody(response));
    } on DioException catch (e) {
      throw _mapRegisterError(e);
    }
  }

  /// Langkah 2 & 5: `POST /auth`. Token yang didapat langsung dipasang ke Dio.
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    _ensureConfigured();
    try {
      final response = await _api.auth(
        email: _normalizeEmail(email),
        password: password,
      );
      final session = AuthSession.fromResponse(_asBody(response));
      if (session.token.isEmpty) {
        throw const ApiException('Login gagal: token tidak diterima server.');
      }
      setAuthToken(session.token);
      return session;
    } on DioException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Langkah 4: `POST /verify_email`. Mengembalikan `verified_at` APA ADANYA.
  ///
  /// Nilainya berakhiran `Z` tapi BUKAN UTC (waktu lokal server, WITA) —
  /// jangan dikonversi ke zona waktu perangkat, hasilnya akan meleset 8 jam.
  Future<String> verifyEmail({
    required String email,
    required String code,
  }) async {
    _ensureConfigured();
    try {
      final response = await _api.verifyEmail(
        email: _normalizeEmail(email),
        code: code.trim(),
      );
      final data =
          (_asBody(response)['data'] as Map?)?.cast<String, dynamic>() ??
          const {};
      return data['verified_at']?.toString() ?? '';
    } on DioException catch (e) {
      throw _mapVerifyError(e);
    }
  }

  /// `POST /resend_verify`. Balasan sukses SELALU sama, terdaftar maupun
  /// tidak — jangan dipakai untuk mengecek keberadaan sebuah email.
  Future<void> resendVerify(String email) async {
    _ensureConfigured();
    try {
      await _api.resendVerify(email: _normalizeEmail(email));
    } on DioException catch (e) {
      throw _mapResendError(e);
    }
  }

  /// `POST /customer/forgot-password` — minta kode reset ke email.
  ///
  /// Balasan sukses SELALU sama, terdaftar maupun tidak — pemanggil harus
  /// tetap lanjut ke layar kode dan tidak boleh menyiratkan email itu ada.
  Future<void> forgotPassword(String email) async {
    _ensureConfigured();
    try {
      await _api.forgotPassword(email: _normalizeEmail(email));
    } on DioException catch (e) {
      throw _network(e) ??
          forgotErrorFor(
            status: e.response?.statusCode,
            message: serverMessage(e),
            validation: rawValidation(e),
          );
    }
  }

  /// `POST /customer/reset-password` — periksa kode lalu ganti kata sandi.
  ///
  /// [email] harus sama dengan yang dipakai di [forgotPassword]. Galatnya
  /// selalu [ResetPasswordException], supaya layar tahu kapan kode perlu
  /// dikosongkan atau diminta ulang.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    _ensureConfigured();
    try {
      await _api.resetPassword(
        email: _normalizeEmail(email),
        code: code.trim(),
        password: password,
      );
    } on DioException catch (e) {
      throw _network(e) ??
          resetErrorFor(
            status: e.response?.statusCode,
            message: serverMessage(e),
            validation: rawValidation(e),
          );
    }
  }

  /// `GET /me` — profil dari klaim token yang sedang dipakai.
  ///
  /// Butuh token Bearer (disisipkan `createDio`). Ingat: `/me` membaca klaim
  /// token, bukan database — `email_verified` di sini ikut membeku bersama
  /// tokennya.
  Future<UserProfile> getMe() async {
    _ensureConfigured();
    try {
      final response = await _api.me();
      return UserProfile.fromResponse(_asBody(response));
    } on DioException catch (e) {
      throw _mapMeError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // ALUR GABUNGAN
  // ---------------------------------------------------------------------------

  /// Langkah 1 + 2: daftar lalu langsung login supaya dapat token.
  ///
  /// Bila pendaftaran sukses tapi login gagal, akun tetap sudah dibuat di
  /// server — [ApiException]-nya diberi pesan yang menyuruh pengguna masuk
  /// manual, bukan mendaftar ulang (mendaftar ulang pasti kena `409`).
  Future<AuthSession> registerAndLogin({
    required String name,
    required String email,
    required String password,
    required String contact,
    required String address,
  }) async {
    await register(
      name: name,
      email: email,
      password: password,
      contact: contact,
      address: address,
    );
    try {
      return await login(email: email, password: password);
    } on ApiException catch (e) {
      throw ApiException(
        'Akun berhasil dibuat, tetapi masuk otomatis gagal '
        '(${e.message}) Silakan masuk memakai email & kata sandi Anda.',
        statusCode: e.statusCode,
      );
    }
  }

  /// Langkah 4 + 5: verifikasi kode LALU login ulang (WAJIB).
  ///
  /// `email_verified` dibekukan di dalam token saat login. Tanpa login ulang,
  /// token lama tetap membawa `email_verified: false` sampai kedaluwarsa
  /// (24 jam) walaupun database sudah `true`.
  Future<AuthSession> verifyEmailAndRefresh({
    required String email,
    required String code,
    required String password,
  }) async {
    await verifyEmail(email: email, code: code);
    try {
      return await login(email: email, password: password);
    } on ApiException catch (e) {
      throw ApiException(
        'Email berhasil diverifikasi, tetapi memperbarui sesi gagal '
        '(${e.message}) Silakan masuk ulang.',
        statusCode: e.statusCode,
      );
    }
  }

  /// Reset kata sandi LALU login dengan kata sandi baru.
  ///
  /// Respons reset tidak berisi token, jadi login wajib menyusul. Token baru
  /// sekaligus membawa `email_verified: true` — reset yang berhasil
  /// membuktikan kodenya sampai ke kotak masuk pemilik.
  ///
  /// Mengembalikan **null** bila kata sandi sudah terganti tetapi login
  /// otomatis gagal: pemanggil mengantar pengguna ke halaman Masuk, bukan
  /// menampilkan galat — reset-nya sendiri sudah berhasil.
  Future<AuthSession?> resetPasswordAndLogin({
    required String email,
    required String code,
    required String password,
  }) async {
    await resetPassword(email: email, code: code, password: password);
    try {
      return await login(email: email, password: password);
    } on ApiException {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PENERJEMAHAN GALAT
  // ---------------------------------------------------------------------------

  /// Galat `forgot-password` → pesan siap tampil.
  ///
  /// [message] adalah `message` mentah dari server — **null** bila body-nya
  /// bukan object. Status diperiksa lebih dulu: limiter per IP membalas `429`
  /// dengan body literal `null`. Dipublikasikan agar tabel galatnya bisa
  /// diuji tanpa server.
  static ApiException forgotErrorFor({
    required int? status,
    String? message,
    Map<String, String> validation = const {},
  }) {
    switch (status) {
      case 429:
        // Ada pesan → batas 3 kode per jam untuk email ini. Tanpa pesan →
        // limiter per IP, sifatnya sebentar.
        return ApiException(
          message == null
              ? 'Terlalu banyak percobaan, tunggu sebentar.'
              : 'Sudah terlalu sering meminta kode. Coba lagi 1 jam lagi.',
          statusCode: 429,
        );
      case 400:
        final friendly = _friendlyValidation(validation);
        return ApiException(
          friendly['email'] ?? 'Format email tidak valid.',
          statusCode: 400,
          validation: friendly,
        );
      case 503:
        return const ApiException(
          'Server sedang bermasalah, coba lagi sebentar lagi.',
          statusCode: 503,
        );
      default:
        return ApiException(
          'Terjadi kesalahan, coba lagi nanti.',
          statusCode: status,
        );
    }
  }

  /// Galat `reset-password` → pesan siap tampil (lihat [forgotErrorFor]).
  static ResetPasswordException resetErrorFor({
    required int? status,
    String? message,
    Map<String, String> validation = const {},
  }) {
    final msg = message?.toLowerCase() ?? '';
    switch (status) {
      case 429:
        // Tanpa pesan → limiter per IP. Dengan pesan → 5 kali salah untuk
        // kode yang sama: kodenya sudah dibatalkan server, bahkan kode yang
        // benar pun tidak diterima lagi.
        if (message == null) {
          return const ResetPasswordException(
            'Terlalu banyak percobaan, tunggu sebentar.',
            statusCode: 429,
          );
        }
        return const ResetPasswordException(
          'Terlalu banyak percobaan salah. Minta kode baru.',
          statusCode: 429,
          mintaKodeBaru: true,
          kosongkanKode: true,
        );
      case 400:
        final friendly = _friendlyValidation(validation);
        if (friendly.isNotEmpty) {
          return ResetPasswordException(
            'Periksa kembali isian Anda.',
            statusCode: 400,
            validation: friendly,
          );
        }
        // "tidak berlaku" dicek lebih dulu: pesan kedaluwarsa tidak memuat
        // kata "salah", tapi urutan ini menjaga bila suatu saat memuatnya.
        // Server sengaja tidak membedakan kedaluwarsa, sudah dipakai, belum
        // pernah diminta, dan email tidak terdaftar.
        if (msg.contains('tidak berlaku')) {
          return const ResetPasswordException(
            'Kode sudah tidak berlaku. Minta kode baru.',
            statusCode: 400,
            mintaKodeBaru: true,
          );
        }
        if (msg.contains('salah')) {
          return const ResetPasswordException(
            'Kode salah, coba periksa lagi.',
            statusCode: 400,
            validation: {'code': 'Kode salah, coba periksa lagi.'},
          );
        }
        return const ResetPasswordException(
          'Data tidak valid. Periksa kembali isian Anda.',
          statusCode: 400,
        );
      case 503:
        return const ResetPasswordException(
          'Server sedang bermasalah, coba lagi sebentar lagi.',
          statusCode: 503,
        );
      default:
        return ResetPasswordException(
          'Terjadi kesalahan, coba lagi nanti.',
          statusCode: status,
        );
    }
  }

  /// Galat jaringan (tanpa respons server), atau null bila server menjawab.
  static ApiException? _network(DioException e) {
    final network = networkErrorMessage(e);
    return network == null ? null : ApiException(network);
  }

  ApiException _mapRegisterError(DioException e) {
    final network = networkErrorMessage(e);
    if (network != null) return ApiException(network);

    final status = e.response?.statusCode;
    final validation = _friendlyValidation(rawValidation(e));
    switch (status) {
      case 400:
        return ApiException(
          validation.isEmpty
              ? (serverMessage(e) ?? 'Data pendaftaran tidak valid.')
              : 'Periksa kembali isian Anda.',
          statusCode: status,
          validation: validation,
        );
      case 409:
        return ApiException(
          'Email ini sudah terdaftar. Coba masuk, atau gunakan email lain.',
          statusCode: status,
        );
      case 429:
        // Limiter per IP: body-nya literal `null`, jadi tidak ada `message`
        // yang bisa dipakai — andalkan status code saja.
        return const ApiException(
          'Terlalu banyak percobaan pendaftaran. Tunggu sebentar lalu coba '
          'lagi.',
          statusCode: 429,
        );
      case 503:
        return const ApiException(
          'Server sedang bermasalah, coba lagi sebentar lagi.',
          statusCode: 503,
        );
      default:
        return ApiException(
          'Terjadi kesalahan, coba lagi nanti.',
          statusCode: status,
        );
    }
  }

  ApiException _mapAuthError(DioException e) {
    final network = networkErrorMessage(e);
    if (network != null) return ApiException(network);

    final status = e.response?.statusCode;
    final message = serverMessage(e) ?? '';
    if (status == 403) {
      // Dua kasus 403 dibedakan lewat pesannya: kredensial salah vs galat
      // apikey/internal (lihat tabel `/auth` di dokumen).
      final isCredential = message.toLowerCase().contains('user tidak');
      return ApiException(
        isCredential
            ? 'Email atau kata sandi salah.'
            : 'Terjadi kesalahan saat login, coba lagi.',
        statusCode: status,
      );
    }
    return ApiException(
      message.isEmpty ? 'Login gagal. Coba lagi.' : message,
      statusCode: status,
    );
  }

  ApiException _mapVerifyError(DioException e) {
    final network = networkErrorMessage(e);
    if (network != null) return ApiException(network);

    final status = e.response?.statusCode;
    final message = (serverMessage(e) ?? '').toLowerCase();
    final validation = _friendlyValidation(rawValidation(e));

    if (status == 400) {
      if (validation.isNotEmpty) {
        return ApiException(
          validation['code'] ?? 'Periksa kembali isian Anda.',
          statusCode: status,
          validation: validation,
        );
      }
      if (message.contains('tidak berlaku')) {
        return const ApiException(
          'Kode sudah tidak berlaku. Minta kirim ulang kode.',
          statusCode: 400,
        );
      }
      if (message.contains('salah')) {
        return const ApiException(
          'Kode salah, coba periksa lagi.',
          statusCode: 400,
        );
      }
      return ApiException(
        serverMessage(e) ?? 'Kode verifikasi tidak valid.',
        statusCode: status,
      );
    }
    if (status == 429) {
      // Ada dua sumber 429 di sini: batas percobaan per kode (ada `message`)
      // dan limiter per IP (body literal `null`, tanpa pesan).
      return ApiException(
        message.isEmpty
            ? 'Terlalu banyak percobaan, coba lagi sebentar lagi.'
            : 'Terlalu banyak percobaan salah. Kode ini sudah tidak berlaku — '
                  'minta kode baru lewat "Kirim ulang".',
        statusCode: 429,
      );
    }
    if (status == 503) {
      return const ApiException(
        'Server sedang bermasalah, coba lagi sebentar lagi.',
        statusCode: 503,
      );
    }
    return ApiException(
      'Terjadi kesalahan, coba lagi nanti.',
      statusCode: status,
    );
  }

  ApiException _mapMeError(DioException e) {
    final network = networkErrorMessage(e);
    if (network != null) return ApiException(network);

    final status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      // Token kedaluwarsa (berlaku 24 jam) atau tidak sah.
      return ApiException(
        'Sesi Anda sudah berakhir. Silakan masuk lagi.',
        statusCode: status,
      );
    }
    return ApiException(
      serverMessage(e) ?? 'Gagal memuat profil. Coba lagi.',
      statusCode: status,
    );
  }

  ApiException _mapResendError(DioException e) {
    final network = networkErrorMessage(e);
    if (network != null) return ApiException(network);

    final status = e.response?.statusCode;
    final message = serverMessage(e) ?? '';
    final validation = _friendlyValidation(rawValidation(e));

    if (status == 400) {
      return ApiException(
        validation['email'] ?? 'Format email tidak valid.',
        statusCode: status,
        validation: validation,
      );
    }
    if (status == 429) {
      // Ada pesan → batas 3 kode per jam untuk email yang sama.
      // Tanpa pesan (body `null`) → limiter per IP, sifatnya sebentar.
      return ApiException(
        message.isEmpty
            ? 'Terlalu banyak percobaan, tunggu sebentar lalu coba lagi.'
            : 'Sudah terlalu sering meminta kode untuk email ini. Coba lagi '
                  '1 jam lagi.',
        statusCode: 429,
      );
    }
    if (status == 503) {
      return const ApiException(
        'Server sedang bermasalah, coba lagi sebentar lagi.',
        statusCode: 503,
      );
    }
    return ApiException(
      'Terjadi kesalahan, coba lagi nanti.',
      statusCode: status,
    );
  }

  // ---------------------------------------------------------------------------
  // UTILITAS
  // ---------------------------------------------------------------------------

  void _ensureConfigured() {
    if (Env.isConfigured) return;
    throw const ApiException(
      'Konfigurasi server belum lengkap. Isi BASE_URL & API_KEY pada file '
      '.env lalu jalankan ulang aplikasi.',
    );
  }

  /// Server menyimpan email huruf kecil semua — samakan sejak dari aplikasi
  /// agar perbandingan lokal (mis. akun tersimpan) tidak meleset.
  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Map<String, dynamic> _asBody(Response<dynamic> response) {
    final data = response.data;
    if (data is Map) return data.cast<String, dynamic>();
    return const {};
  }
}

/// Galat `reset-password`, dengan petunjuk untuk layar kode.
class ResetPasswordException extends ApiException {
  const ResetPasswordException(
    super.message, {
    super.statusCode,
    super.validation,
    this.mintaKodeBaru = false,
    this.kosongkanKode = false,
  });

  /// Kode yang dipegang pengguna sudah mati — sorot tombol "Kirim ulang".
  final bool mintaKodeBaru;

  /// Isi field kode tidak lagi berguna (sudah dibatalkan server).
  final bool kosongkanKode;
}

/// Ubah map validasi mentah (`field` → nama aturan) menjadi pesan yang ramah.
///
/// Nama aturan mentah seperti `min` tidak boleh ditampilkan ke pengguna.
Map<String, String> _friendlyValidation(Map<String, String> raw) {
  return {
    for (final entry in raw.entries)
      entry.key: _validationMessage(entry.key, entry.value),
  };
}

String _validationMessage(String field, String rule) {
  const labels = {
    'name': 'Nama',
    'email': 'Email',
    'password': 'Kata sandi',
    'contact': 'Nomor HP',
    'address': 'Alamat',
    'code': 'Kode',
  };
  final label = labels[field] ?? field;

  switch ('$field.$rule') {
    case 'name.max':
      return 'Nama maksimal 255 karakter.';
    case 'email.email':
      return 'Format email tidak valid.';
    case 'email.max':
      return 'Email maksimal 255 karakter.';
    case 'password.min':
      return 'Kata sandi minimal 8 karakter.';
    case 'password.max':
      return 'Kata sandi maksimal 72 karakter.';
    case 'contact.min':
      return 'Nomor HP minimal 8 karakter.';
    case 'contact.max':
      return 'Nomor HP maksimal 20 karakter.';
    case 'address.max':
      return 'Alamat maksimal 500 karakter.';
    case 'code.len':
      return 'Kode harus 6 digit angka.';
    case 'code.number':
      return 'Kode hanya boleh berisi angka.';
  }
  return switch (rule) {
    'required' => '$label wajib diisi.',
    'min' => '$label terlalu pendek.',
    'max' => '$label terlalu panjang.',
    'len' => 'Panjang $label tidak sesuai.',
    'number' => '$label hanya boleh berisi angka.',
    'email' => 'Format email tidak valid.',
    _ => '$label tidak valid.',
  };
}

/// Instance global siap pakai (sejalan dengan `authStore` & `cartStore`).
final AuthRepository authRepository = AuthRepository(AuthApi(dio));
