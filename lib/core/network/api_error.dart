import 'dart:convert';

import 'package:dio/dio.dart';

/// Galat API yang sudah diterjemahkan menjadi pesan siap tampil ke pengguna.
///
/// Dilempar oleh repository (lihat `lib/data/auth_repository.dart`) supaya
/// halaman UI cukup menampilkan [message] tanpa perlu tahu soal Dio/HTTP.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.validation = const {},
  });

  /// Pesan ramah pengguna (bahasa Indonesia).
  final String message;

  /// Kode HTTP bila ada. Null untuk galat jaringan/konfigurasi.
  final int? statusCode;

  /// Galat per field, sudah ramah pengguna: nama field → pesan.
  /// Kosong bila galatnya bukan galat validasi.
  final Map<String, String> validation;

  bool get hasValidation => validation.isNotEmpty;

  /// True bila server menolak karena token tidak sah/kedaluwarsa — pemanggil
  /// sebaiknya mengeluarkan pengguna dan meminta masuk ulang.
  bool get isUnauthenticated => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'ApiException(${statusCode ?? '-'}): $message';
}

/// Ambil pesan error yang jelas dari [error].
///
/// Prioritas:
/// 1. Field `message` (atau `error`/`msg`) dari body respons server (Dio).
/// 2. Jenis error koneksi/timeout Dio → pesan ramah.
/// 3. [fallback].
String apiErrorMessage(
  Object? error, {
  String fallback = 'Terjadi kesalahan. Coba lagi.',
}) {
  if (error is ApiException) return error.message;
  if (error is DioException) {
    // 1. Pesan dari body respons server (mis. {"message": "..."}).
    final serverMsg = serverMessage(error);
    if (serverMsg != null && serverMsg.isNotEmpty) return serverMsg;

    // 2. Jenis error jaringan.
    final networkMsg = networkErrorMessage(error);
    if (networkMsg != null) return networkMsg;

    final code = error.response?.statusCode;
    return code != null ? 'Gagal (kode $code). Coba lagi.' : fallback;
  }
  return fallback;
}

/// Pesan untuk galat jaringan/koneksi. Null bila galatnya berasal dari
/// respons server (artinya server terjangkau, cek status code-nya).
String? networkErrorMessage(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return 'Koneksi timeout. Periksa jaringan Anda.';
    case DioExceptionType.connectionError:
      return 'Gagal terhubung ke server. Periksa jaringan Anda.';
    case DioExceptionType.badCertificate:
      return 'Sertifikat server tidak valid.';
    case DioExceptionType.cancel:
      return 'Permintaan dibatalkan.';
    case DioExceptionType.badResponse:
      return null;
    case DioExceptionType.unknown:
      return error.response == null
          ? 'Gagal terhubung ke server. Periksa jaringan Anda.'
          : null;
  }
}

/// Field `message` dari body respons, bila ada.
///
/// Aman untuk body yang BUKAN object — limiter per IP membalas `429` dengan
/// body literal `null`, jadi jangan pernah mengasumsikan hasil parse berupa
/// Map (lihat API_REGISTER_FLUTTER.md bagian "Tiga Jenis Batas Laju").
String? serverMessage(DioException error) => _messageFromBody(
  error.response?.data,
);

/// Map validasi mentah dari server: nama field → nama aturan yang dilanggar
/// (mis. `{"email": "email", "password": "min"}`). Kosong bila tidak ada.
Map<String, String> rawValidation(DioException error) {
  final map = _asMap(error.response?.data);
  final raw = map?['validation'];
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      entry.key.toString(): entry.value.toString(),
  };
}

/// Cari field pesan dari body respons (Map, atau String JSON).
String? _messageFromBody(Object? data) {
  final map = _asMap(data);
  if (map == null) return null;
  final msg = map['message'] ?? map['error'] ?? map['msg'];
  final text = msg?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

/// Body respons sebagai Map, atau null bila bentuknya lain (`null`, list,
/// string non-JSON, dst.).
Map<dynamic, dynamic>? _asMap(Object? data) {
  if (data is Map) return data;
  if (data is String && data.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) return decoded;
    } catch (_) {
      // Body bukan JSON — abaikan.
    }
  }
  return null;
}
