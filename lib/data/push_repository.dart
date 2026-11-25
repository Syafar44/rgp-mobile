import 'package:dio/dio.dart';

import '../core/config/env.dart';
import '../core/network/api_error.dart';
import '../core/network/dio_client.dart';
import '../core/utils/app_log.dart';
import 'api/push_api.dart';

/// Identitas pembeli di OneSignal.
///
/// Berbeda dari repository lain, di sini galat **tidak** dilempar: push adalah
/// pelengkap, jadi kegagalannya tidak boleh menghentikan apa pun yang sedang
/// dilakukan pembeli. Semua kegagalan menghasilkan null dan tercatat di log.
class PushRepository {
  PushRepository(this._api);

  final PushApi _api;

  static const String _tag = 'PUSH';

  /// Sebab kegagalan terakhir, siap ditampilkan. Null bila terakhir berhasil.
  ///
  /// Ada karena [externalId] sengaja tidak melempar galat: tanpa ini, satu-
  /// satunya jejak kegagalan hanya di log.
  String? lastFailure;

  /// `external_id` untuk `OneSignal.login()`. Null bila belum bisa didapat.
  ///
  /// Penanganan status mengikuti dokumen backend:
  /// - `401` token kedaluwarsa — aplikasi tidak memaksa keluar dari sini;
  ///   layar lain yang memakai token akan lebih dulu mengarahkan ke login.
  /// - `500` server belum dikonfigurasi — diam saja, dicoba lagi saat aplikasi
  ///   dibuka berikutnya.
  /// - `404` rutenya belum ada di server. Perhatikan: 404 di sini BUKAN
  ///   konvensi "data kosong" yang dipakai endpoint pesanan — pesan server
  ///   berbunyi `Not Found` dari router, artinya endpointnya memang belum
  ///   dideploy.
  Future<String?> externalId() async {
    if (!Env.isConfigured) return null;
    try {
      final res = await _api.identity();
      final data = res.data is Map ? (res.data as Map)['data'] : null;
      final id = data is Map ? (data['external_id'] ?? '').toString().trim() : '';
      if (id.isEmpty) {
        lastFailure = 'Server menjawab tanpa `external_id`.';
        AppLog.warn(
          _tag,
          'push_identity tanpa external_id',
          detail: logTrim(res.data),
        );
        return null;
      }
      lastFailure = null;
      AppLog.info(
        _tag,
        'push_identity OK',
        detail: 'external_id=${redact(id)} (${id.length} karakter)',
      );
      return id;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final sebab = switch (status) {
        401 =>
          'Token tidak valid/kedaluwarsa — push dilewati sampai pembeli '
              'masuk lagi.',
        404 =>
          'Endpoint GET /pos/app/v1/push_identity BELUM ADA di server '
              '(router menjawab "Not Found"). Selama belum dideploy, '
              'perangkat tidak mungkin tertaut — ini di sisi backend, bukan '
              'aplikasi.',
        500 =>
          'Server belum dikonfigurasi — dicoba lagi saat aplikasi dibuka '
              'berikutnya.',
        _ => serverMessage(e) ?? e.message ?? 'galat jaringan',
      };
      lastFailure = 'HTTP $status — $sebab';
      AppLog.warn(
        _tag,
        'gagal mengambil push_identity (HTTP $status)',
        detail: sebab,
      );
      return null;
    } catch (e) {
      lastFailure = e.toString();
      AppLog.error(_tag, 'push_identity gagal', detail: e.toString());
      return null;
    }
  }
}

/// Instance global siap pakai.
final PushRepository pushRepository = PushRepository(PushApi(dio));
