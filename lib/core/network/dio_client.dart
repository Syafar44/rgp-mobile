import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

/// Token Bearer aktif.
///
/// Sementara disimpan di memori. Saat login sudah terintegrasi, ganti dengan
/// secure storage seperti pada project svp_app (`SecureStorageService`).
String? _authToken;

/// Set / hapus token Bearer yang dipakai semua request.
void setAuthToken(String? token) => _authToken = token;

/// Membuat instance Dio yang sudah dikonfigurasi.
///
/// Pola mengikuti svp_app: header `apikey`, timeout 15 detik, interceptor
/// untuk menyisipkan token Bearer, dan log request/response saat debug.
Dio createDio({String? apiKey}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'apikey': apiKey ?? Env.apiKey},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _authToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  // DEBUG: log penuh request/response/error ke console (hanya saat debug).
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ),
    );
  }

  return dio;
}

/// Instance Dio global siap pakai di seluruh aplikasi.
final Dio dio = createDio();
