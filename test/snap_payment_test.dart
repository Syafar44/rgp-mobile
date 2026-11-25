// Kontrak pembayaran Snap Midtrans.
//
// Core API (`/midtrans/charge`) belum aktif di akun production, jadi tagihan
// dibuat lewat Snap: responsnya hanya `redirect_url`, tanpa nomor VA, gambar
// QR, maupun instruksi. Lihat "Panduan Integrasi Snap Midtrans".

import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/data/api/payment_api.dart';
import 'package:roti_gembung_panglima_app/data/models/checkout_result.dart';
import 'package:roti_gembung_panglima_app/data/models/payment_charge.dart';
import 'package:roti_gembung_panglima_app/data/models/payment_method.dart';
import 'package:roti_gembung_panglima_app/data/payment_repository.dart';

void main() {
  group('respons Snap', () {
    // Contoh dari dokumen backend, apa adanya.
    final snap = PaymentCharge.fromJson({
      'order_id': 'INV-2026-0006',
      'payment_type': 'bank_transfer',
      'bank': 'bni',
      'redirect_url': 'https://app.midtrans.com/snap/v4/redirection/6f1c',
      'snap_token': '6f1c',
      'gross_amount': 154440,
      'transaction_status': 'pending',
    });

    test('dikenali sebagai Snap, bukan Core API', () {
      expect(snap.isSnap, isTrue);
      expect(snap.hasRedirect, isTrue);
      // Tidak ada yang bisa digambar aplikasi — semuanya di halaman Snap.
      expect(snap.hasQr, isFalse);
      expect(snap.hasVa, isFalse);
      expect(snap.hasBill, isFalse);
      expect(snap.hasInstruction, isFalse);
    });

    test('field pentingnya terbaca', () {
      expect(snap.orderId, 'INV-2026-0006');
      expect(snap.grossAmount, 154440);
      expect(snap.status, PaymentTxStatus.pending);
      expect(snap.snapToken, '6f1c');
      expect(
        snap.redirectUrl,
        'https://app.midtrans.com/snap/v4/redirection/6f1c',
      );
    });

    test('masa berlaku tetap 15 menit', () {
      final dibuat = DateTime(2026, 9, 26, 14, 0);
      final c = PaymentCharge.fromJson({
        'order_id': 'X',
        'redirect_url': 'https://app.midtrans.com/snap/v4/redirection/x',
      }, createdAt: dibuat);
      expect(c.expiresAt, DateTime(2026, 9, 26, 14, 15));
    });

    test('respons Core API tidak salah dikenali sebagai Snap', () {
      // Begitu Core API aktif lagi, VA/QR kembali digambar aplikasi sendiri.
      final core = PaymentCharge.fromJson({
        'order_id': 'X',
        'payment_type': 'bank_transfer',
        'bank': 'bni',
        'va_number': '988123456789',
        'redirect_url': '',
      });
      expect(core.isSnap, isFalse);
      expect(core.hasVa, isTrue);
    });
  });

  group('penentuan endpoint charge', () {
    test('bawaan kembali ke Core API', () {
      expect(PaymentApi.defaultChargePath, '/midtrans/charge');
    });

    test('server yang menentukan gateway, bukan aplikasi', () {
      // Inti desainnya: gateway bisa dipindah dari server tanpa merilis
      // aplikasi. Saklar paksa hanya untuk keadaan darurat dan kini mati.
      expect(PaymentApi.paksaSnap, isFalse);
      expect(
        PaymentApi.resolveChargePath('/midtrans/snap'),
        '/midtrans/snap',
      );
      expect(
        PaymentApi.resolveChargePath('/gateway-lain/charge'),
        '/gateway-lain/charge',
      );
    });

    test('server diam → pakai bawaan, bukan buntu', () {
      expect(
        PaymentApi.resolveChargePath(''),
        PaymentApi.defaultChargePath,
      );
    });

    test('tanpa charge_path & tanpa paksa, tagihan belum bisa dibuat', () {
      // `CheckoutResult.canCharge` menuntut `charge_path` begitu saklar paksa
      // mati — halaman pembayaran menampilkan pesan jujur ketimbang menebak
      // endpoint.
      final co = CheckoutResult.fromJson({
        'order_id': 'APP1790497676815',
        'outlet_id': 19,
        'status': 'pending',
        'subtotal_amount': 3000,
      });

      expect(co.canCharge, PaymentApi.paksaSnap);
    });

    test('dengan charge_path, tagihan bisa dibuat', () {
      final co = CheckoutResult.fromJson({
        'order_id': 'APP1790497676815',
        'outlet_id': 19,
        'charge_path': '/midtrans/charge',
      });

      expect(co.canCharge, isTrue);
    });

    test('tanpa nomor pesanan, tagihan tetap tidak bisa dibuat', () {
      final co = CheckoutResult.fromJson({'outlet_id': 19});
      expect(co.canCharge, isFalse);
    });
  });

  group('penyaringan metode', () {
    PaymentMethod m(String value, String type) =>
        PaymentMethod.fromJson({'id': 1, 'title': value, 'value': value, 'type': type});

    test('metode yang belum aktif di Midtrans disembunyikan', () {
      final hasil = PaymentRepository.hanyaYangAktif([
        m('qris', 'qris'),
        m('gopay', 'gopay'),
        m('bni', 'bank_transfer'),
        m('bca', 'bank_transfer'),
        m('mandiri', 'bank_transfer'),
        m('credit_card', 'credit_card'),
      ]).map((e) => e.value).toList();

      // Memilihnya hanya menghasilkan halaman Snap kosong.
      expect(hasil, isNot(contains('gopay')));
      expect(hasil, isNot(contains('bca')));
      expect(hasil, isNot(contains('credit_card')));
    });

    test('metode yang tersedia tetap utuh & urutannya terjaga', () {
      final hasil = PaymentRepository.hanyaYangAktif([
        m('qris', 'qris'),
        m('bni', 'bank_transfer'),
        m('bri', 'bank_transfer'),
        m('permata', 'bank_transfer'),
        m('cimb', 'bank_transfer'),
        m('bsi', 'bank_transfer'),
        m('mandiri', 'bank_transfer'),
      ]).map((e) => e.value).toList();

      expect(hasil, [
        'qris', 'bni', 'bri', 'permata', 'cimb', 'bsi', 'mandiri',
      ]);
    });

    test('daftar kosong tidak membuat crash', () {
      expect(PaymentRepository.hanyaYangAktif(const []), isEmpty);
    });
  });
}
