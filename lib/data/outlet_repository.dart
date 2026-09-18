import 'package:dio/dio.dart';

import '../core/config/env.dart';
import '../core/network/api_error.dart';
import '../core/network/dio_client.dart';
import 'api/outlet_api.dart';
import 'models/outlet.dart';

/// Mengambil daftar outlet dari API. Semua galat Dio diterjemahkan menjadi
/// [ApiException] berisi pesan bahasa Indonesia siap tampil (pola sama dengan
/// `AuthRepository`).
class OutletRepository {
  OutletRepository(this._api);

  final OutletApi _api;

  /// Outlet terdekat dari [lat]/[long], diurutkan dari yang terdekat oleh
  /// server. Mengembalikan daftar kosong bila `data` tidak ada.
  Future<List<Outlet>> nearby({
    required double lat,
    required double long,
    int limit = 10,
  }) async {
    _ensureConfigured();
    try {
      final response = await _api.nearby(lat: lat, long: long, limit: limit);
      final body = response.data;
      final list = body is Map ? body['data'] : null;
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => Outlet.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    final network = networkErrorMessage(e);
    if (network != null) return ApiException(network);

    final status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      return ApiException(
        'Sesi Anda sudah berakhir. Silakan masuk lagi.',
        statusCode: status,
      );
    }
    return ApiException(
      serverMessage(e) ?? 'Gagal memuat daftar outlet. Coba lagi.',
      statusCode: status,
    );
  }

  void _ensureConfigured() {
    if (Env.isConfigured) return;
    throw const ApiException(
      'Konfigurasi server belum lengkap. Isi BASE_URL & API_KEY pada file '
      '.env lalu jalankan ulang aplikasi.',
    );
  }
}

/// Instance global siap pakai.
final OutletRepository outletRepository = OutletRepository(OutletApi(dio));
