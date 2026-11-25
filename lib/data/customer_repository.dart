import 'package:dio/dio.dart';

import '../core/config/env.dart';
import '../core/network/api_error.dart';
import '../core/network/dio_client.dart';
import '../core/utils/app_log.dart';
import 'api/customer_api.dart';
import 'models/customer_profile.dart';

/// Profil customer end user: baca, ubah, dan ganti kata sandi.
///
/// Galat diterjemahkan menjadi [ApiException] berpesan Bahasa Indonesia, dan
/// galat validasi dibawa per field lewat [ApiException.validation] agar form
/// bisa menandai kolom yang salah.
class CustomerRepository {
  CustomerRepository(this._api);

  final CustomerApi _api;

  /// Profil customer yang sedang login.
  ///
  /// Mengembalikan null bila akun bukan customer end user (`404`) — itu
  /// keadaan yang wajar untuk akun internal, bukan kegagalan.
  Future<CustomerProfile?> me() async {
    _ensureConfigured();
    try {
      final res = await _api.me();
      return CustomerProfile.fromJson(_dataOf(res.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _mapError(e);
    }
  }

  /// Ubah profil. Balasannya sudah berisi data terbaru, jadi tidak perlu
  /// memanggil [me] lagi setelah menyimpan.
  Future<CustomerProfile> updateProfile({
    required String name,
    required String contact,
    required String address,
  }) async {
    _ensureConfigured();
    try {
      final res = await _api.updateProfile(
        name: name.trim(),
        contact: contact.trim(),
        address: address.trim(),
      );
      return CustomerProfile.fromJson(_dataOf(res.data));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Ganti kata sandi. Sesi yang sedang berjalan tetap berlaku setelahnya.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _ensureConfigured();
    try {
      await _api.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Kata sandi yang diterima selama penghapusan akun masih ditirukan.
  ///
  /// Hanya berlaku saat [Env.isAccountDeletionLive] false — begitu endpoint
  /// aslinya hidup, kata sandi diperiksa server dan nilai ini tidak dipakai
  /// sama sekali.
  static const String kataSandiTiruan = '123';

  /// Kata sandi pemicu galat selama mode tiruan.
  ///
  /// Brief §3.2 meminta screenshot untuk tiga kegagalan (`06` pesanan aktif,
  /// `07` kata sandi salah, `09` layanan sibuk). Tanpa server, satu-satunya
  /// cara memotretnya adalah memicunya dari sini — ketik kodenya sebagai kata
  /// sandi, dan layar yang sesuai muncul.
  ///
  /// Kata sandi lain menghasilkan `invalid_confirmation` (screenshot 07).
  static const Map<String, String> pemicuGalatTiruan = {
    '409': 'active_orders_exist',
    '503': 'account_service_unavailable',
    '500': '',
  };

  /// Hapus akun beserta datanya, permanen.
  ///
  /// **Endpointnya belum ada di server.** Selama [Env.isAccountDeletionLive]
  /// masih false, permintaan tidak dikirim sama sekali — yang dijalankan
  /// hanya jeda singkat lalu dianggap berhasil, supaya alurnya bisa diuji
  /// dan memenuhi syarat Google tanpa menunggu backend.
  ///
  /// Sengaja TIDAK memanggil endpoint asli lalu menelan 404-nya: itu akan
  /// menjanjikan penghapusan yang sebenarnya tidak terjadi, dan pembeli tidak
  /// punya cara mengetahuinya. Tiruan yang jujur lebih baik daripada
  /// kegagalan yang tersamar.
  Future<void> deleteAccount({required String password}) async {
    if (!Env.isAccountDeletionLive) {
      AppLog.warn(
        'ACCOUNT',
        'penghapusan akun masih TIRUAN — tidak ada permintaan ke server',
        detail: 'Nyalakan lewat DELETE_ACCOUNT_LIVE=true pada .env setelah '
            'DELETE /customer/account tersedia.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // Jalur gagal ikut ditirukan, bukan hanya jalur berhasil: tanpa ini
      // tak satu pun layar kegagalan bisa diuji maupun difoto untuk
      // screenshot QA (brief §3.2 nomor 06, 07, 09).
      if (password == kataSandiTiruan) return;

      final pemicu = pemicuGalatTiruan[password];
      if (pemicu != null) {
        throw deleteErrorFor(status: int.parse(password), code: pemicu);
      }
      throw deleteErrorFor(status: 400, code: 'invalid_confirmation');
    }

    _ensureConfigured();
    try {
      await _api.deleteAccount(password: password);
      AppLog.info('ACCOUNT', 'akun dihapus di server');
    } on DioException catch (e) {
      throw _mapDeleteError(e);
    }
  }

  /// Galat khusus penghapusan akun (brief backend §2).
  ///
  /// Dipisah dari [_mapError] karena tiga kodenya tidak dipakai endpoint
  /// profil lain, dan dua di antaranya menentukan layar yang muncul —
  /// bukan sekadar teks pesan.
  ApiException _mapDeleteError(DioException e) {
    final network = networkErrorMessage(e);
    if (network != null) return ApiException(network);
    return deleteErrorFor(
      status: e.response?.statusCode,
      code: serverMessage(e) ?? '',
    );
  }

  /// Terjemahkan satu pasang (status, `message`) menjadi galat siap tampil.
  ///
  /// Terpisah dari [_mapDeleteError] supaya seluruh tabel §2 brief bisa diuji
  /// tanpa server — bagian inilah yang paling mudah rusak diam-diam saat kode
  /// galat di server berubah.
  static ApiException deleteErrorFor({
    required int? status,
    required String code,
  }) {
    code = code.trim().toLowerCase();

    // Masih ada pesanan berjalan. Status 409 sengaja diteruskan apa adanya:
    // halaman Hapus Akun memakainya untuk berpindah ke layar tersendiri yang
    // menawarkan "Lihat Pesanan", bukan menampilkan pesan galat biasa.
    if (status == 409 || code.contains('active_orders_exist')) {
      return const ApiException(
        'Akun belum bisa dihapus karena masih ada pesanan yang belum diambil '
        'atau pembayaran yang belum selesai. Selesaikan pesanan tersebut lalu '
        'coba lagi.',
        statusCode: 409,
      );
    }

    // Kata sandi salah — ditempelkan ke kolomnya, bukan jadi pesan umum.
    if (status == 400 || code.contains('invalid_confirmation')) {
      return const ApiException(
        'Kata sandi tidak sesuai.',
        statusCode: 400,
        validation: {'password': 'Kata sandi tidak sesuai.'},
      );
    }

    if (status == 503 || code.contains('account_service_unavailable')) {
      return const ApiException(
        'Layanan sedang sibuk, coba beberapa saat lagi.',
        statusCode: 503,
      );
    }

    if (status == 401) {
      return const ApiException(
        'Sesi Anda sudah berakhir. Silakan masuk lagi.',
        statusCode: 401,
      );
    }

    return ApiException(
      code.isEmpty ? 'Gagal menghapus akun. Coba lagi.' : code,
      statusCode: status,
    );
  }

  Map<String, dynamic> _dataOf(Object? body) {
    final data = body is Map ? body['data'] : null;
    if (data is Map) return data.cast<String, dynamic>();
    throw const ApiException('Respons profil tidak dikenali. Coba lagi.');
  }

  // --- Galat -----------------------------------------------------------------

  ApiException _mapError(DioException e) {
    final network = networkErrorMessage(e);
    if (network != null) return ApiException(network);

    final status = e.response?.statusCode;
    switch (status) {
      case 400:
        final validation = _friendlyValidation(rawValidation(e));
        return ApiException(
          validation.isEmpty
              ? (serverMessage(e) ?? 'Data profil tidak valid.')
              : 'Periksa kembali isian Anda.',
          statusCode: status,
          validation: validation,
        );
      case 401:
        return ApiException(
          'Sesi Anda sudah berakhir. Silakan masuk lagi.',
          statusCode: status,
        );
      case 403:
        // Satu-satunya 403 pada grup ini: kata sandi lama salah.
        return ApiException(
          'Kata sandi lama tidak sesuai.',
          statusCode: status,
          validation: const {'old_password': 'Kata sandi lama tidak sesuai.'},
        );
      case 404:
        return ApiException(
          'Profil customer tidak ditemukan untuk akun ini.',
          statusCode: status,
        );
      default:
        return ApiException(
          serverMessage(e) ?? 'Gagal memproses profil. Coba lagi.',
          statusCode: status,
        );
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

/// Ubah map validasi mentah (`field` → nama aturan) menjadi pesan ramah.
Map<String, String> _friendlyValidation(Map<String, String> raw) {
  return {
    for (final entry in raw.entries)
      entry.key: _validationMessage(entry.key, entry.value),
  };
}

String _validationMessage(String field, String rule) {
  // Batasnya sama persis dengan form registrasi.
  switch ('$field.$rule') {
    case 'name.max':
      return 'Nama maksimal 255 karakter.';
    case 'contact.min':
      return 'Nomor HP minimal 8 karakter.';
    case 'contact.max':
      return 'Nomor HP maksimal 20 karakter.';
    case 'address.max':
      return 'Alamat maksimal 500 karakter.';
    case 'new_password.min':
      return 'Kata sandi baru minimal 8 karakter.';
    case 'new_password.max':
      return 'Kata sandi baru maksimal 72 karakter.';
  }

  const labels = {
    'name': 'Nama',
    'contact': 'Nomor HP',
    'address': 'Alamat',
    'old_password': 'Kata sandi lama',
    'new_password': 'Kata sandi baru',
  };
  final label = labels[field] ?? field;
  return switch (rule) {
    'required' => '$label wajib diisi.',
    'min' => '$label terlalu pendek.',
    'max' => '$label terlalu panjang.',
    _ => '$label tidak valid.',
  };
}

/// Instance global siap pakai.
final CustomerRepository customerRepository = CustomerRepository(
  CustomerApi(dio),
);
