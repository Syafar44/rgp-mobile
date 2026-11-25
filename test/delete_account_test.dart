// Tabel galat penghapusan akun — brief backend "Hapus Akun Pembeli" §2.
//
// Dua di antaranya menentukan LAYAR yang muncul, bukan sekadar teks: 409
// membawa pembeli ke layar "Lihat Pesanan", dan 400 menempel di kolom kata
// sandi. Salah petakan berarti pembeli terjebak tanpa tahu harus berbuat apa.

import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/data/api/customer_api.dart';
import 'package:roti_gembung_panglima_app/data/customer_repository.dart';

void main() {
  group('tabel galat §2', () {
    test('409 active_orders_exist → dipertahankan agar layar C muncul', () {
      final e = CustomerRepository.deleteErrorFor(
        status: 409,
        code: 'active_orders_exist',
      );

      // Halaman konfirmasi memeriksa `statusCode == 409` untuk berpindah
      // layar; kalau kodenya hilang, pembeli hanya melihat pesan galat biasa.
      expect(e.statusCode, 409);
      expect(e.message, contains('belum diambil'));
    });

    test('400 invalid_confirmation → menempel di kolom kata sandi', () {
      final e = CustomerRepository.deleteErrorFor(
        status: 400,
        code: 'invalid_confirmation',
      );

      expect(e.statusCode, 400);
      expect(e.validation['password'], isNotNull);
    });

    test('503 account_service_unavailable → pesan "coba beberapa saat"', () {
      final e = CustomerRepository.deleteErrorFor(
        status: 503,
        code: 'account_service_unavailable',
      );

      expect(e.statusCode, 503);
      expect(e.message.toLowerCase(), contains('sibuk'));
    });

    test('401 → sesi berakhir', () {
      final e = CustomerRepository.deleteErrorFor(status: 401, code: '');
      expect(e.statusCode, 401);
      expect(e.message.toLowerCase(), contains('sesi'));
    });

    test('500 & kode tak dikenal → pesan umum, bukan layar khusus', () {
      final e = CustomerRepository.deleteErrorFor(status: 500, code: '');
      expect(e.statusCode, 500);
      expect(e.message, contains('Gagal menghapus akun'));
      expect(e.validation, isEmpty);
    });

    test('kode dikenali walau statusnya tidak seperti yang didokumentasikan',
        () {
      // Server sudah beberapa kali mengganti kode status tanpa kabar; yang
      // lebih stabil justru `message`-nya.
      expect(
        CustomerRepository.deleteErrorFor(
          status: 400,
          code: 'active_orders_exist',
        ).statusCode,
        409,
      );
    });
  });

  test('path penghapusan: `/account`, bukan di bawah `/customer`', () {
    // Dikonfirmasi tim backend. Berbeda dari endpoint profil lain
    // (`/customer/me`, `/customer/profile`, `/customer/password`), jadi
    // gampang keliru bila ditebak dari polanya.
    expect(CustomerApi.deleteAccountPath, '/account');
  });
}
