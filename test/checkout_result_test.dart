// Kontrak parsing `POST /pos/app/v1/outlets/:id/checkout` — memakai respons
// nyata dari server (log aplikasi, 18 Sep 2026).
//
// Bentuknya BERBEDA dari dokumen API Aplikasi Customer bagian 4: server kini
// memakai alur bayar-dulu.

import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/data/api/payment_api.dart';
import 'package:roti_gembung_panglima_app/data/models/checkout_result.dart';

void main() {
  const response = {
    'order_id': 'APP1789701426894',
    'outlet_id': 13,
    'status': 'pending',
    'status_label': 'Menunggu pembayaran',
    'subtotal_amount': 42000,
    'payment_method': 'qris',
    'provider': 'sumopod',
    'charge_path': '/sumopod/charge',
    'expires_at': '2026-09-18T12:17:06+08:00',
    'pickup_at': '2026-09-18T12:17:06+08:00',
    'pos_orders_id': null,
    'created_at': '2026-09-18T11:17:07+08:00',
  };

  test('membaca seluruh field respons checkout', () {
    final result = CheckoutResult.fromJson(response);

    // `order_id` berupa string, bukan id numerik seperti di dokumen.
    expect(result.orderId, 'APP1789701426894');
    expect(result.outletId, 13);
    expect(result.status, 'pending');
    expect(result.statusLabel, 'Menunggu pembayaran');
    expect(result.subtotalAmount, 42000);
    expect(result.paymentMethod, 'qris');
    expect(result.provider, 'sumopod');
    expect(result.chargePath, '/sumopod/charge');
    expect(result.expiresAt, isNotNull);
    expect(result.pickupAt, isNotNull);
    expect(result.createdAt, isNotNull);
  });

  test('pos_orders_id null berarti pesanan belum dibayar', () {
    final result = CheckoutResult.fromJson(response);

    expect(result.posOrderId, isNull);
    expect(result.isAwaitingPayment, isTrue);
  });

  test('charge_path menentukan endpoint tagihan yang dipanggil', () {
    final result = CheckoutResult.fromJson(response);

    expect(result.canCharge, isTrue);
  });

  test('tanpa charge_path, tagihan tetap bisa dibuat lewat Snap', () {
    // Dulu aturannya "aplikasi tidak boleh menebak endpoint" dan ini
    // `isFalse`. Aturan itu sengaja ditangguhkan lewat `PaymentApi.paksaSnap`
    // selama respons checkout masih mengirim `/midtrans/charge` padahal Core
    // API belum aktif. Harapan tes ini ikut berbalik saat saklarnya dimatikan.
    final result = CheckoutResult.fromJson({
      'order_id': 'APP123',
      'subtotal_amount': 1000,
    });

    expect(result.canCharge, PaymentApi.paksaSnap);
  });

  test('nomor pesanan tetap syarat mutlak', () {
    final result = CheckoutResult.fromJson({'subtotal_amount': 1000});
    expect(result.canCharge, isFalse);
  });

  test('pesanan yang sudah dibayar membawa pos_orders_id', () {
    final result = CheckoutResult.fromJson({
      ...response,
      'pos_orders_id': 188003,
    });

    expect(result.posOrderId, 188003);
    expect(result.isAwaitingPayment, isFalse);
  });
}
