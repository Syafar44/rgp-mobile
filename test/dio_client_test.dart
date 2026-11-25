// Penyisipan header oleh interceptor Dio.
//
// `/pos/app/v1/push_identity` hanya menerima token Bearer — header `apikey`
// tidak boleh ikut. Aturan itu diuji di sini karena kalau bocor lagi, satu
// endpoint akan gagal diam-diam tanpa ada yang berubah di layar.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/core/network/dio_client.dart';

/// Jalankan interceptor request pada [options] (dimutasi di tempat).
void _terapkan(RequestOptions options) {
  final dio = createDio();
  final wrapper = dio.interceptors.whereType<InterceptorsWrapper>().first;
  wrapper.onRequest(options, RequestInterceptorHandler());
}

void main() {
  test('request biasa tetap membawa header apikey', () {
    final options = RequestOptions(path: '/pos/app/v1/orders');
    _terapkan(options);

    expect(options.headers.containsKey('apikey'), isTrue);
  });

  test('noApiKey() membuang header apikey', () {
    final options = RequestOptions(
      path: '/pos/app/v1/push_identity',
      extra: noApiKey().extra!,
    );
    _terapkan(options);

    expect(options.headers.containsKey('apikey'), isFalse);
  });

  test('token Bearer tetap dikirim walau apikey dibuang', () {
    setAuthToken('token-uji');
    addTearDown(() => setAuthToken(null));

    final options = RequestOptions(
      path: '/pos/app/v1/push_identity',
      extra: noApiKey().extra!,
    );
    _terapkan(options);

    expect(options.headers['Authorization'], 'Bearer token-uji');
    expect(options.headers.containsKey('apikey'), isFalse);
  });
}
