import 'package:dio/dio.dart';

import '../config/env.dart';
import '../utils/app_log.dart';
import 'network_logger.dart';

/// Token Bearer aktif.
///
/// Disimpan di memori; nilai awalnya dipulihkan dari penyimpanan lokal oleh
/// [AuthStore.load] saat aplikasi start (lihat `lib/data/auth_store.dart`).
String? _authToken;

/// Set / hapus token Bearer yang dipakai semua request.
void setAuthToken(String? token) => _authToken = token;

/// Token Bearer yang sedang dipakai (null bila belum masuk).
String? get authToken => _authToken;

/// Penanda `Options.extra` untuk request yang TIDAK boleh membawa header
/// `apikey`.
///
/// Sebagian rute hanya menerima token Bearer dan menolak/mengabaikan `apikey`,
/// jadi penyisipannya dibuat bisa dimatikan per-request ketimbang mencabutnya
/// untuk semua endpoint — lihat [noApiKey].
const String kSkipApiKey = 'skip_apikey';

/// `Options` siap pakai untuk request tanpa header `apikey`.
Options noApiKey() => Options(extra: const {kSkipApiKey: true});

/// Dipanggil sekali saat server menyatakan sesi tidak lagi sah (HTTP 401).
///
/// Disuntikkan dari `main.dart` (`authStore.logout`) supaya lapisan `core`
/// tidak bergantung pada `data` — arah ketergantungan di project ini selalu
/// `data` → `core`.
void Function()? onUnauthenticated;

/// Prefix layanan pembayaran.
///
/// 401/403 dari sini berbicara tentang `X-API-Key` layanan pembayaran, **bukan**
/// sesi pembeli — mengeluarkannya dari akun gara-gara kunci gateway salah
/// adalah kesalahan yang jauh lebih merugikan daripada galat aslinya.
const String _paymentPrefix = '/payment/api/v2';

/// True bila [err] menandakan sesi pembeli sudah tidak berlaku.
///
/// Tiga syarat, semuanya perlu:
/// - status **401** saja. 403 dipakai untuk hal lain (mis. kata sandi lama
///   salah pada `PATCH /customer/password`), dan mengeluarkan pembeli di situ
///   akan terasa seperti kerusakan.
/// - request memang **membawa token**. Tanpa ini, gagal login di `POST /auth`
///   (yang juga 401) akan memicu logout — tidak berbahaya, tapi menyesatkan.
/// - **bukan** endpoint pembayaran (lihat [_paymentPrefix]).
bool _isSessionExpired(DioException err) {
  if (err.response?.statusCode != 401) return false;
  final o = err.requestOptions;
  if (o.headers['Authorization'] == null) return false;
  return !o.path.startsWith(_paymentPrefix);
}

/// Membuat instance Dio yang sudah dikonfigurasi.
///
/// Pola mengikuti svp_app: header `apikey`, timeout 15 detik, interceptor
/// untuk menyisipkan token Bearer, dan log request/response saat debug.
///
/// `baseUrl` dan `apikey` dibaca dari [Env] (file `.env`). Keduanya diisi
/// saat request dibuat, bukan dibekukan saat instance dibuat, supaya urutan
/// pemuatan `.env` tidak jadi masalah.
Dio createDio({String? apiKey}) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        options.baseUrl = Env.baseUrl;
        if (options.extra[kSkipApiKey] == true) {
          options.headers.remove('apikey');
        } else {
          options.headers['apikey'] = apiKey ?? Env.apiKey;
        }
        final token = _authToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (err, handler) {
        if (_isSessionExpired(err)) {
          AppLog.warn(
            'AUTH',
            'sesi berakhir — pembeli dikeluarkan',
            detail: '401 pada ${err.requestOptions.method} '
                '${err.requestOptions.path}',
          );
          // Dipanggil di semua layar sekaligus: tanpa ini, pembeli terjebak
          // pada aplikasi yang tampak masuk tapi setiap aksinya ditolak.
          onUnauthenticated?.call();
        }
        handler.next(err);
      },
    ),
  );

  // DEBUG: catat lalu lintas jaringan (ringkas, rahasia disamarkan) ke console
  // sekaligus ke penyangga di memori yang bisa dibaca lewat halaman Log.
  if (AppLog.enabled) dio.interceptors.add(NetworkLogger());

  return dio;
}

/// Instance Dio global siap pakai di seluruh aplikasi.
final Dio dio = createDio();
