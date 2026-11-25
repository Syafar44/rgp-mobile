import 'dart:convert';

import 'package:dio/dio.dart';

import '../utils/app_log.dart';

/// Pencatat lalu lintas jaringan, ringkas dan aman dibagikan.
///
/// Dibuat sendiri alih-alih memakai `LogInterceptor` bawaan Dio karena tiga
/// alasan:
/// - **Rahasia disamarkan.** Bawaan Dio mencetak `apikey`, `X-API-Key`, dan
///   token Bearer apa adanya; log sering ditempel ke chat/tiket.
/// - **Satu permintaan = beberapa baris pendek**, bukan belasan baris header
///   yang jarang dibaca — jauh lebih mudah ditelusuri.
/// - **Lama permintaan dicatat**, sehingga lambatnya sebuah endpoint langsung
///   kelihatan.
class NetworkLogger extends Interceptor {
  static const String _tag = 'NET';
  static const String _startKey = 'log_start_ms';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now().millisecondsSinceEpoch;
    AppLog.info(
      _tag,
      '→ ${options.method} ${_path(options)}',
      detail: _requestDetail(options),
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    AppLog.info(
      _tag,
      '← ${response.statusCode} ${response.requestOptions.method} '
      '${_path(response.requestOptions)} ${_elapsed(response.requestOptions)}',
      // TIDAK dipotong: body utuh inilah yang dibaca dari halaman Log saat
      // mencocokkan respons API dengan yang tampil di layar. Konsol tetap
      // ringkas (lihat `LogEntry.toConsole`), dan `AppLog.maxDetail` yang
      // menjaga batas atasnya.
      detail: _pretty(response.data),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    AppLog.error(
      _tag,
      '✗ ${status ?? err.type.name} ${err.requestOptions.method} '
      '${_path(err.requestOptions)} ${_elapsed(err.requestOptions)}',
      detail: err.response != null ? _pretty(err.response?.data) : err.message,
    );
    handler.next(err);
  }

  String _path(RequestOptions o) {
    final query = o.queryParameters.isEmpty
        ? ''
        : '?${o.queryParameters.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    return '${o.path}$query';
  }

  String _elapsed(RequestOptions o) {
    final start = o.extra[_startKey];
    if (start is! int) return '';
    return '(${DateTime.now().millisecondsSinceEpoch - start}ms)';
  }

  /// Ringkasan permintaan: kunci auth yang dipakai (disamarkan) + body.
  String _requestDetail(RequestOptions o) {
    final auth = <String>[];
    final headers = o.headers;
    if (headers['Authorization'] != null) {
      auth.add('bearer=${redact(headers['Authorization']?.toString())}');
    }
    if (headers['apikey'] != null) {
      auth.add('apikey=${redact(headers['apikey']?.toString())}');
    }
    if (headers['X-API-Key'] != null) {
      auth.add('x-api-key=${redact(headers['X-API-Key']?.toString())}');
    }

    final parts = <String>[];
    if (auth.isNotEmpty) parts.add(auth.join(' '));
    if (o.data != null) parts.add(_pretty(_maskBody(o.data)));
    return parts.join('\n    ');
  }

  /// Samarkan field sensitif di body sebelum dicatat.
  Object? _maskBody(Object? data) {
    const secrets = {
      'password',
      'old_password',
      'new_password',
      'token',
      'token_id',
    };
    if (data is Map) {
      return {
        for (final e in data.entries)
          e.key.toString(): secrets.contains(e.key.toString().toLowerCase())
              ? '•••'
              : _maskBody(e.value),
      };
    }
    if (data is List) return data.map(_maskBody).toList();
    return data;
  }

  /// JSON dengan indentasi — jauh lebih mudah dibaca di halaman Log daripada
  /// satu baris panjang, dan tetap sah untuk ditempel ke tiket.
  static const JsonEncoder _json = JsonEncoder.withIndent('  ');

  String _pretty(Object? data) {
    if (data == null) return 'null';
    if (data is Map || data is List) {
      try {
        return _json.convert(data);
      } catch (_) {
        return data.toString();
      }
    }
    return data.toString();
  }
}
