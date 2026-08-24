import 'dart:convert';

import 'package:dio/dio.dart';

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
  if (error is DioException) {
    // 1. Pesan dari body respons server (mis. {"message": "..."}).
    final serverMsg = _messageFromBody(error.response?.data);
    if (serverMsg != null && serverMsg.isNotEmpty) return serverMsg;

    // 2. Jenis error jaringan.
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Koneksi timeout. Periksa jaringan Anda.';
      case DioExceptionType.connectionError:
        return 'Gagal terhubung ke server. Periksa jaringan Anda.';
      case DioExceptionType.badCertificate:
        return 'Sertifikat server tidak valid.';
      case DioExceptionType.cancel:
        return 'Permintaan dibatalkan.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
      default:
        final code = error.response?.statusCode;
        return code != null ? 'Gagal (kode $code). Coba lagi.' : fallback;
    }
  }
  return fallback;
}

/// Cari field pesan dari body respons (Map, atau String JSON).
String? _messageFromBody(Object? data) {
  Map<dynamic, dynamic>? map;
  if (data is Map) {
    map = data;
  } else if (data is String && data.isNotEmpty) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) map = decoded;
    } catch (_) {
      // Body bukan JSON — abaikan.
    }
  }
  if (map == null) return null;
  final msg = map['message'] ?? map['error'] ?? map['msg'];
  final text = msg?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}
