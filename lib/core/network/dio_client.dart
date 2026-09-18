import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

/// Token Bearer aktif.
///
/// Disimpan di memori; nilai awalnya dipulihkan dari penyimpanan lokal oleh
/// [AuthStore.load] saat aplikasi start (lihat `lib/data/auth_store.dart`).
String? _authToken;

/// Set / hapus token Bearer yang dipakai semua request.
void setAuthToken(String? token) => _authToken = token;

/// Token Bearer yang sedang dipakai (null bila belum masuk).
String? get authToken => _authToken;

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
        options.headers['apikey'] = apiKey ?? Env.apiKey;
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
