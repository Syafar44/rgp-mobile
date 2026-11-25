// Penanganan sesi berakhir.
//
// Sebelumnya tujuh repository sama-sama memetakan 401 jadi pesan "Sesi Anda
// sudah berakhir", tapi hanya halaman Profile yang benar-benar mengeluarkan
// pembeli. Akibatnya pembeli terjebak: aplikasi tampak masuk, tapi setiap
// aksinya ditolak satu per satu.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/core/network/dio_client.dart';

/// Jalankan interceptor error pada [err], catat apakah logout terpicu.
bool _memicuLogout(DioException err) {
  var keluar = false;
  final sebelumnya = onUnauthenticated;
  onUnauthenticated = () => keluar = true;
  try {
    final dio = createDio();
    final wrapper = dio.interceptors.whereType<InterceptorsWrapper>().first;
    // `handler.next(err)` meneruskan galatnya ke rantai berikutnya. Di test
    // tidak ada yang menunggunya, jadi zona ini menelannya agar tidak muncul
    // sebagai galat asinkron liar yang menggagalkan test.
    runZonedGuarded(
      () => wrapper.onError(err, ErrorInterceptorHandler()),
      (_, _) {},
    );
  } finally {
    onUnauthenticated = sebelumnya;
  }
  return keluar;
}

DioException _galat({
  required int status,
  required String path,
  bool denganToken = true,
}) {
  final options = RequestOptions(
    path: path,
    headers: denganToken ? {'Authorization': 'Bearer abc'} : {},
  );
  return DioException(
    requestOptions: options,
    response: Response<dynamic>(requestOptions: options, statusCode: status),
  );
}

void main() {
  test('401 pada endpoint ber-token mengeluarkan pembeli', () {
    expect(_memicuLogout(_galat(status: 401, path: '/pos/app/v1/orders')), isTrue);
  });

  test('401 saat login TIDAK mengeluarkan siapa pun', () {
    // `POST /auth` juga menjawab 401 untuk kata sandi salah. Memicu logout di
    // sini tidak berbahaya, tapi menyesatkan saat menelusuri masalah.
    expect(
      _memicuLogout(_galat(status: 401, path: '/auth', denganToken: false)),
      isFalse,
    );
  });

  test('401 dari layanan pembayaran TIDAK mengeluarkan pembeli', () {
    // Di sana 401/403 berbicara soal `X-API-Key` gateway, bukan sesi pembeli.
    // Mengeluarkannya dari akun gara-gara kunci gateway salah jauh lebih
    // merugikan daripada galat aslinya.
    expect(
      _memicuLogout(
        _galat(status: 401, path: '/payment/api/v2/midtrans/snap'),
      ),
      isFalse,
    );
  });

  test('403 tidak dianggap sesi berakhir', () {
    // Dipakai untuk hal lain, mis. kata sandi lama salah pada
    // `PATCH /customer/password`.
    expect(
      _memicuLogout(_galat(status: 403, path: '/customer/password')),
      isFalse,
    );
  });

  test('galat lain dibiarkan apa adanya', () {
    for (final status in [400, 404, 422, 500]) {
      expect(
        _memicuLogout(_galat(status: status, path: '/pos/app/v1/orders')),
        isFalse,
        reason: 'HTTP $status',
      );
    }
  });
}
