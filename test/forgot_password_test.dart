// Lupa kata sandi (`/customer/forgot-password` → `/customer/reset-password`
// → `/auth`).
//
// Server dipalsukan lewat adapter Dio, jadi seluruh alur layar teruji —
// termasuk 429 dengan body literal `null` yang membuat parsing naif crash.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:roti_gembung_panglima_app/core/network/dio_client.dart';
import 'package:roti_gembung_panglima_app/data/auth_repository.dart';
import 'package:roti_gembung_panglima_app/data/auth_store.dart';
import 'package:roti_gembung_panglima_app/pages/auth/email_login_page.dart';

/// Satu jawaban palsu: status + body (null = body literal `null`).
typedef Jawaban = ({int status, Object? body});

/// Server palsu: antrean jawaban per path, plus catatan request yang masuk.
class _ServerPalsu implements HttpClientAdapter {
  final Map<String, List<Jawaban>> antrean = {};
  final List<({String path, Map<String, dynamic> body})> masuk = [];

  void jawab(String path, int status, [Object? body]) =>
      (antrean[path] ??= []).add((status: status, body: body));

  List<Map<String, dynamic>> bodyKe(String path) => [
    for (final r in masuk)
      if (r.path == path) r.body,
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    masuk.add((
      path: path,
      body: options.data is Map
          ? (options.data as Map).cast<String, dynamic>()
          : const {},
    ));
    // Probe jaringan (`ensureNetworkReady`) — cukup dijawab cepat.
    if (path.startsWith('/pos/app/v1/orders')) {
      return ResponseBody.fromString('{}', 200, headers: _json);
    }
    final daftar = antrean[path];
    final j = (daftar == null || daftar.isEmpty)
        ? (status: 500, body: {'message': 'tidak ada jawaban palsu'})
        : (daftar.length == 1 ? daftar.first : daftar.removeAt(0));
    return ResponseBody.fromString(
      jsonEncode(j.body),
      j.status,
      headers: _json,
    );
  }

  static const _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

const _forgot = '/customer/forgot-password';

/// Tombol kirim ulang yang disorot (`OutlinedButton.icon` = subclass).
final _tombolSorot = find.byWidgetPredicate((w) => w is OutlinedButton);
const _reset = '/customer/reset-password';
const _auth = '/auth';

void main() {
  group('tabel galat forgot-password', () {
    ApiExceptionMatcher msg(String m) => ApiExceptionMatcher(m);

    test('429 body null → limiter per IP', () {
      expect(
        AuthRepository.forgotErrorFor(status: 429),
        msg('Terlalu banyak percobaan, tunggu sebentar.'),
      );
    });
    test('429 dengan pesan → jatah 3 kode per jam', () {
      expect(
        AuthRepository.forgotErrorFor(
          status: 429,
          message: 'terlalu banyak permintaan kode, coba lagi satu jam lagi',
        ),
        msg('Sudah terlalu sering meminta kode. Coba lagi 1 jam lagi.'),
      );
    });
    test('400, 503, 500', () {
      expect(
        AuthRepository.forgotErrorFor(
          status: 400,
          message: 'error validation',
          validation: {'email': 'email'},
        ),
        msg('Format email tidak valid.'),
      );
      expect(
        AuthRepository.forgotErrorFor(status: 503),
        msg('Server sedang bermasalah, coba lagi sebentar lagi.'),
      );
      expect(
        AuthRepository.forgotErrorFor(status: 500),
        msg('Terjadi kesalahan, coba lagi nanti.'),
      );
    });
  });

  group('tabel galat reset-password', () {
    test('validasi → pesan per field, bukan nama aturan', () {
      final e = AuthRepository.resetErrorFor(
        status: 400,
        message: 'error validation',
        validation: {'code': 'len', 'password': 'min'},
      );
      expect(e.validation['code'], 'Kode harus 6 digit angka.');
      expect(e.validation['password'], 'Kata sandi minimal 8 karakter.');
    });
    test('kode salah → galat di field kode', () {
      final e = AuthRepository.resetErrorFor(
        status: 400,
        message: 'kode reset password salah',
      );
      expect(e.validation['code'], 'Kode salah, coba periksa lagi.');
      expect(e.mintaKodeBaru, isFalse);
    });
    test('tidak berlaku → minta kode baru', () {
      final e = AuthRepository.resetErrorFor(
        status: 400,
        message: 'kode reset password tidak berlaku, minta kode baru',
      );
      expect(e.message, 'Kode sudah tidak berlaku. Minta kode baru.');
      expect(e.mintaKodeBaru, isTrue);
      expect(e.kosongkanKode, isFalse);
    });
    test('5× salah → kosongkan kode + minta kode baru', () {
      final e = AuthRepository.resetErrorFor(
        status: 429,
        message: 'terlalu banyak percobaan, minta kode baru',
      );
      expect(e.message, 'Terlalu banyak percobaan salah. Minta kode baru.');
      expect(e.mintaKodeBaru && e.kosongkanKode, isTrue);
    });
    test('429 body null → limiter per IP, kode tetap', () {
      final e = AuthRepository.resetErrorFor(status: 429);
      expect(e.message, 'Terlalu banyak percobaan, tunggu sebentar.');
      expect(e.mintaKodeBaru || e.kosongkanKode, isFalse);
    });
  });

  group('alur layar', () {
    late _ServerPalsu server;
    late HttpClientAdapter asli;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dotenv.loadFromString(envString: 'BASE_URL=https://api.tes\nAPI_KEY=k');
      server = _ServerPalsu();
      asli = dio.httpClientAdapter;
      dio.httpClientAdapter = server;
    });

    tearDown(() {
      dio.httpClientAdapter = asli;
      dotenv.clean();
      authStore.logout();
    });

    /// Request palsu selesai di microtask, tapi probe jaringan & Dio memakai
    /// timer — pompa beberapa kali sampai tenang.
    Future<void> tunggu(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    /// Masuk → Lupa kata sandi → kirim kode → layar 2.
    Future<void> keLayarKode(
      WidgetTester tester, {
      String email = 'budi@contoh.com',
    }) async {
      server.jawab(_forgot, 200, {
        'message': 'Bila email terdaftar, kode reset password sudah dikirim',
      });
      await tester.pumpWidget(const MaterialApp(home: EmailLoginPage()));
      await tester.enterText(find.byType(TextField).first, email);
      await tester.tap(find.text('Lupa kata sandi?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kirim Kode'));
      await tunggu(tester);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    }

    Future<void> isi(
      WidgetTester tester, {
      String kode = '482913',
      String sandi = 'rahasiaBaru1',
      String? ulang,
    }) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), kode);
      await tester.enterText(fields.at(1), sandi);
      await tester.enterText(fields.at(2), ulang ?? sandi);
      await tester.pump();
    }

    /// Gulir ke tombol kirim ulang — kotak galat/info mendorongnya keluar
    /// layar tes, dan `ListView` tidak membangun yang di luar layar.
    Future<void> keBawah(WidgetTester tester) async {
      await tester.drag(find.byType(ListView).last, const Offset(0, -800));
      await tester.pump();
    }

    Future<void> simpan(WidgetTester tester) async {
      await tester.tap(find.text('Simpan Kata Sandi Baru'));
      await tunggu(tester);
    }

    testWidgets(
      'email dari Masuk diisi, dinormalisasi, layar 2 selalu terbuka',
      (tester) async {
        await keLayarKode(tester, email: '  Budi@Contoh.COM ');
        expect(server.bodyKe(_forgot).single, {'email': 'budi@contoh.com'});
        expect(find.text('Atur Ulang Kata Sandi'), findsOneWidget);
        expect(find.text('budi@contoh.com'), findsOneWidget);
        expect(find.text('Kirim ulang kode dalam 60s'), findsOneWidget);
        await tester.pump(const Duration(seconds: 61));
      },
    );

    testWidgets('validasi lokal mengunci tombol', (tester) async {
      await keLayarKode(tester);
      FilledButton tombol() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Simpan Kata Sandi Baru'),
      );

      await isi(tester, kode: '4829', sandi: 'rahasiaBaru1');
      expect(tombol().onPressed, isNull, reason: 'kode belum 6 digit');

      await isi(tester, sandi: 'pendek');
      expect(find.text('Kata sandi minimal 8 karakter.'), findsOneWidget);
      expect(tombol().onPressed, isNull);

      await isi(tester, ulang: 'rahasiaLain1');
      expect(find.text('Konfirmasi kata sandi tidak sama.'), findsOneWidget);
      expect(tombol().onPressed, isNull);

      await isi(tester);
      expect(tombol().onPressed, isNotNull);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('berhasil → token baru, email terverifikasi, ke Beranda', (
      tester,
    ) async {
      await keLayarKode(tester);
      server.jawab(_reset, 200, {
        'message': 'Password berhasil diganti, silakan login kembali',
      });
      server.jawab(_auth, 200, {
        'data': {
          'id': 55,
          'name': 'Budi',
          'email': 'budi@contoh.com',
          'email_verified': true,
          'token': 'token-baru',
        },
      });
      await isi(tester);
      await simpan(tester);
      await tester.pumpAndSettle();

      // Satu field password saja — konfirmasi tidak dikirim.
      expect(server.bodyKe(_reset).single, {
        'email': 'budi@contoh.com',
        'code': '482913',
        'password': 'rahasiaBaru1',
      });
      expect(server.bodyKe(_auth).single['password'], 'rahasiaBaru1');
      expect(authStore.session.value?.token, 'token-baru');
      expect(authStore.currentUser.value?.emailVerified, isTrue);
      expect(find.text('Kata sandi berhasil diganti'), findsOneWidget);
    });

    testWidgets('masuk otomatis gagal → kembali ke Masuk, email terisi', (
      tester,
    ) async {
      await keLayarKode(tester);
      server.jawab(_reset, 200, {'message': 'ok'});
      server.jawab(_auth, 403, {'message': 'user tidak ditemukan'});
      await isi(tester);
      await simpan(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Kata sandi sudah diganti, silakan masuk.'),
        findsOneWidget,
      );
      expect(find.text('budi@contoh.com'), findsOneWidget);
      expect(authStore.session.value, isNull);
    });

    testWidgets(
      'email tidak terdaftar → kode tidak berlaku + kirim ulang disorot',
      (tester) async {
        await keLayarKode(tester, email: 'tidakada@contoh.com');
        server.jawab(_reset, 400, {
          'message': 'kode reset password tidak berlaku, minta kode baru',
        });
        await isi(tester);
        await simpan(tester);

        expect(
          find.text('Kode sudah tidak berlaku. Minta kode baru.'),
          findsOneWidget,
        );
        await keBawah(tester);
        expect(_tombolSorot, findsOneWidget);
        await tester.pump(const Duration(seconds: 61));
        expect(find.text('Minta Kode Baru'), findsOneWidget);
      },
    );

    testWidgets('kode salah → galat di field kode, kode tetap', (tester) async {
      await keLayarKode(tester);
      server.jawab(_reset, 400, {'message': 'kode reset password salah'});
      await isi(tester);
      await simpan(tester);

      expect(find.text('Kode salah, coba periksa lagi.'), findsOneWidget);
      expect(find.text('482913'), findsOneWidget);
      await keBawah(tester);
      expect(_tombolSorot, findsNothing);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('5× salah → kode dikosongkan, minta kode baru', (tester) async {
      await keLayarKode(tester);
      server.jawab(_reset, 429, {
        'message': 'terlalu banyak percobaan, minta kode baru',
      });
      await isi(tester);
      await simpan(tester);

      expect(
        find.text('Terlalu banyak percobaan salah. Minta kode baru.'),
        findsOneWidget,
      );
      expect(find.text('482913'), findsNothing);
      await keBawah(tester);
      expect(_tombolSorot, findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('429 body null tidak crash', (tester) async {
      await keLayarKode(tester);
      server.jawab(_reset, 429, null);
      await isi(tester);
      await simpan(tester);

      expect(tester.takeException(), isNull);
      expect(
        find.text('Terlalu banyak percobaan, tunggu sebentar.'),
        findsOneWidget,
      );
      expect(find.text('482913'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('kirim ulang: hitung mundur, kode lama dikosongkan', (
      tester,
    ) async {
      await keLayarKode(tester);
      await isi(tester);
      // Belum boleh selama hitung mundur.
      await tester.tap(find.text('Kirim ulang kode dalam 60s'));
      await tester.pump();
      expect(server.bodyKe(_forgot), hasLength(1));

      await tester.pump(const Duration(seconds: 60));
      await tester.tap(find.text('Tidak menerima kode? Kirim ulang'));
      await tunggu(tester);

      expect(server.bodyKe(_forgot), [
        {'email': 'budi@contoh.com'},
        {'email': 'budi@contoh.com'},
      ]);
      expect(find.text('482913'), findsNothing);
      expect(find.textContaining('Kode sebelumnya'), findsOneWidget);
      await keBawah(tester);
      expect(find.textContaining(RegExp(r'Kirim ulang kode dalam \d+s')), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('forgot-password 429 body null tidak crash', (tester) async {
      server.jawab(_forgot, 429, null);
      await tester.pumpWidget(const MaterialApp(home: EmailLoginPage()));
      await tester.enterText(find.byType(TextField).first, 'budi@contoh.com');
      await tester.tap(find.text('Lupa kata sandi?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kirim Kode'));
      await tunggu(tester);

      expect(tester.takeException(), isNull);
      expect(
        find.text('Terlalu banyak percobaan, tunggu sebentar.'),
        findsOneWidget,
      );
      expect(
        find.text('Lupa Kata Sandi'),
        findsOneWidget,
        reason: 'tetap di layar 1',
      );
    });
  });
}

/// Cocokkan pesan sebuah [ApiException].
class ApiExceptionMatcher extends CustomMatcher {
  ApiExceptionMatcher(String message)
    : super('ApiException dengan pesan', 'message', message);

  @override
  Object? featureValueOf(dynamic actual) => (actual as dynamic).message;
}
