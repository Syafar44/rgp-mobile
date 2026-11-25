// Kontrak parsing pembayaran Midtrans — memakai contoh respons dari dokumen
// "API Pembayaran Midtrans" (charge & status).

import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/data/models/payment_charge.dart';

void main() {
  group('PaymentCharge — QRIS', () {
    const response = {
      'order_id': 'INV-2026-0002',
      'transaction_id': '31908fc9-8363-465c-a108-3d9245113a0c',
      'payment_type': 'qris',
      'qr_code':
          'https://merchants-app.sbx.midtrans.com/v4/qris/gopay/A12026/qr-code',
      'gross_amount': 150000,
      'transaction_status': 'pending',
      'instruction_html': '<div>...</div>',
    };

    test('membaca field utama & QR', () {
      final charge = PaymentCharge.fromJson(response);

      expect(charge.orderId, 'INV-2026-0002');
      expect(charge.transactionId, '31908fc9-8363-465c-a108-3d9245113a0c');
      expect(charge.paymentType, 'qris');
      expect(charge.grossAmount, 150000);
      expect(charge.status, PaymentTxStatus.pending);
      expect(charge.hasQr, isTrue);
      expect(charge.hasInstruction, isTrue);
      // Field yang kosong tidak dikirim server.
      expect(charge.hasVa, isFalse);
      expect(charge.hasBill, isFalse);
      expect(charge.hasDeeplink, isFalse);
    });

    test('masa berlaku 15 menit dihitung aplikasi', () {
      final dibuat = DateTime(2026, 9, 23, 11, 0);
      final charge = PaymentCharge.fromJson(response, createdAt: dibuat);

      // Server tidak mengirim `expires_at`; aturannya selalu 15 menit.
      expect(charge.expiresAt, DateTime(2026, 9, 23, 11, 15));
    });
  });

  group('PaymentCharge — metode lain', () {
    test('bank transfer membawa bank & nomor virtual account', () {
      final charge = PaymentCharge.fromJson({
        'order_id': 'INV-2026-0001',
        'payment_type': 'bank_transfer',
        'bank': 'bni',
        'va_number': '9882218886262973',
        'gross_amount': 150000,
        'transaction_status': 'pending',
      });

      expect(charge.hasVa, isTrue);
      expect(charge.bank, 'bni');
      expect(charge.vaNumber, '9882218886262973');
      expect(charge.hasQr, isFalse);
    });

    test('mandiri bill membawa dua kode sekaligus', () {
      final charge = PaymentCharge.fromJson({
        'order_id': 'INV-2026-0004',
        'payment_type': 'echannel',
        'bill_key': '978387567777',
        'biller_code': '70012',
        'gross_amount': 150000,
        'transaction_status': 'pending',
      });

      // Keduanya harus ada; satu saja tidak cukup untuk membayar.
      expect(charge.hasBill, isTrue);
      expect(charge.billKey, '978387567777');
      expect(charge.billerCode, '70012');
    });

    test('gopay membawa QR sekaligus deeplink', () {
      final charge = PaymentCharge.fromJson({
        'order_id': 'INV-2026-0003',
        'payment_type': 'gopay',
        'qr_code': 'https://api.sandbox.midtrans.com/v2/gopay/x/qr-code',
        'deeplink_url': 'https://simulator.sandbox.midtrans.com/v2/deeplink/x',
        'gross_amount': 150000,
        'transaction_status': 'pending',
      });

      expect(charge.hasQr, isTrue);
      expect(charge.hasDeeplink, isTrue);
    });

    test('kartu kredit membawa redirect 3DS', () {
      final charge = PaymentCharge.fromJson({
        'order_id': 'INV-2026-0005',
        'payment_type': 'credit_card',
        'redirect_url': 'https://api.midtrans.com/v2/token/rba/redirect/x',
        'gross_amount': 150000,
        'transaction_status': 'pending',
      });

      expect(charge.hasRedirect, isTrue);
    });
  });

  group('PaymentTxStatus', () {
    test('memetakan status Midtrans ke logika aplikasi', () {
      expect(PaymentTxStatus.fromCode('pending').isPending, isTrue);
      expect(PaymentTxStatus.fromCode('settlement').isPaid, isTrue);
      // `capture` adalah bentuk lunas untuk kartu kredit.
      expect(PaymentTxStatus.fromCode('capture').isPaid, isTrue);

      for (final mati in ['expire', 'cancel', 'deny', 'failure']) {
        expect(PaymentTxStatus.fromCode(mati).isDead, isTrue, reason: mati);
        expect(PaymentTxStatus.fromCode(mati).isPaid, isFalse, reason: mati);
      }
    });

    test('status asing tidak dianggap lunas maupun mati', () {
      final status = PaymentTxStatus.fromCode('status_baru');
      expect(status, PaymentTxStatus.unknown);
      expect(status.isPaid, isFalse);
      expect(status.isDead, isFalse);
    });
  });

  group('PaymentStatus (GET /status)', () {
    test('membaca status beserta instruksi pembayaran', () {
      final status = PaymentStatus.fromJson({
        'order_id': 'INV-2026-0001',
        'provider': 'midtrans',
        'transaction_status': 'settlement',
        'payment_type': 'bank_transfer',
        'gross_amount': 150000,
        'payment_instruction': {
          'bank': 'bni',
          'va_number': '9882218886262973',
        },
      });

      expect(status.orderId, 'INV-2026-0001');
      expect(status.provider, 'midtrans');
      expect(status.status.isPaid, isTrue);
      expect(status.bank, 'bni');
      expect(status.vaNumber, '9882218886262973');
    });

    test('tanpa payment_instruction tetap terbaca', () {
      final status = PaymentStatus.fromJson({
        'order_id': 'INV-2026-0002',
        'transaction_status': 'expire',
        'payment_type': 'qris',
      });

      expect(status.status.isDead, isTrue);
      expect(status.bank, '');
      expect(status.vaNumber, '');
    });
  });

  group('PaymentCalculation', () {
    test('membaca hasil hitungan biaya dari server', () {
      final calc = PaymentCalculation.fromJson({
        'value': 'qris',
        'provider': 'midtrans',
        'amount': 100000,
        'addons': 300,
        'percentage': 0.7,
        'fee': 1000,
        'total': 101000,
      });

      expect(calc.amount, 100000);
      expect(calc.fee, 1000);
      expect(calc.total, calc.amount + calc.fee);
    });
  });
}
