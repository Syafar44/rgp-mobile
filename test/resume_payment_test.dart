// Alur "lanjutkan pembayaran" untuk pesanan yang ditinggalkan sebelum lunas.
//
// Pesanan berstatus `pending` belum punya id numerik (pesanan POS baru
// terbentuk setelah pembayaran masuk), jadi halaman status memang tidak bisa
// memuatnya. Yang benar adalah mengantar pembeli kembali ke pembayarannya.

import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/data/api/payment_api.dart';
import 'package:roti_gembung_panglima_app/data/models/order.dart';

void main() {
  // Respons `GET /orders?status=active` yang sebenarnya (log 28 Sep 2026).
  // Perhatikan kode statusnya: `menunggu_pembayaran`, BUKAN `pending` seperti
  // pada respons checkout. Ejaan yang tak dikenali dulu jatuh ke `unknown`,
  // sehingga pesanannya diarahkan ke halaman status dan berakhir di layar
  // galat "nomornya belum dikenali sistem".
  const dariDaftarPesanan = {
    'id': 0,
    'document_number': 'APP1790555372184',
    'outlet_id': 19,
    'outlet_name': 'Roti Gembung Panglima - Juanda 1',
    'status': 'menunggu_pembayaran',
    'status_label': 'Menunggu pembayaran',
    'total_amount': 3000,
    'item_count': 1,
    'pickup_at': '2026-09-28T09:29:32+08:00',
    'created_at': '2026-09-28T08:29:32+08:00',
    'order_id': 'APP1790555372184',
    'payment_method': 'bri',
    'provider': 'midtrans',
    'charge_path': '/midtrans/charge',
    'expires_at': '2026-09-28T08:44:32+08:00',
  };

  group('respons nyata daftar pesanan', () {
    test('`menunggu_pembayaran` dikenali sama dengan `pending`', () {
      final order = Order.fromJson(dariDaftarPesanan);

      expect(order.status, OrderStatus.pending);
      expect(order.isAwaitingPayment, isTrue);
      expect(order.status.isActive, isTrue);
    });

    test('bekal pembayarannya lengkap', () {
      final co = Order.fromJson(dariDaftarPesanan).toCheckoutResult();

      expect(co.orderId, 'APP1790555372184');
      expect(co.paymentMethod, 'bri');
      expect(co.subtotalAmount, 3000);
      expect(co.canCharge, isTrue);
    });

    test('batas waktu dibaca dari server, bukan dihitung ulang', () {
      // Tanpa ini hitung mundur akan mulai dari 15 menit penuh lagi setiap
      // kali halaman pembayaran dibuka — padahal tagihannya dibuat 08:29.
      final co = Order.fromJson(dariDaftarPesanan).toCheckoutResult();

      expect(co.expiresAt, isNotNull);
      expect(co.expiresAt!.toUtc(), DateTime.utc(2026, 9, 28, 0, 44, 32));
    });
  });

  const belumBayar = {
    'id': 0,
    'order_id': 'APP1790402093801',
    'document_number': 'APP1790402093801',
    'outlet_id': 19,
    'outlet_name': 'Roti Gembung Panglima - Juanda 1',
    'status': 'pending',
    'status_label': 'Menunggu pembayaran',
    'total_amount': 3000,
    'subtotal_amount': 3000,
    'item_count': 1,
  };

  test('status `pending` dikenali sebagai belum dibayar & masih berjalan', () {
    final order = Order.fromJson(belumBayar);

    expect(order.status, OrderStatus.pending);
    expect(order.isAwaitingPayment, isTrue);
    // Tetap di tab Berjalan — pembeli masih harus menindaklanjutinya.
    expect(order.status.isActive, isTrue);
    expect(order.status.isDone, isFalse);
    // Tanpa id numerik, halaman status memang tidak bisa memuatnya.
    expect(order.isUsable, isFalse);
  });

  test('bisa dibentuk ulang jadi bekal halaman pembayaran', () {
    final co = Order.fromJson(belumBayar).toCheckoutResult();

    expect(co.orderId, 'APP1790402093801');
    expect(co.outletId, 19);
    expect(co.subtotalAmount, 3000);
    expect(co.canCharge, isTrue);
    expect(co.isAwaitingPayment, isTrue);
  });

  test('charge_path dari server dipakai apa adanya', () {
    final order = Order.fromJson({
      ...belumBayar,
      'charge_path': '/gateway-lain/charge',
      'payment_method': 'bri',
      'provider': 'lain',
    });

    expect(order.toCheckoutResult().chargePath, '/gateway-lain/charge');
    expect(order.toCheckoutResult().paymentMethod, 'bri');
  });

  test('tanpa charge_path, jatuh ke bawaan — bukan jalan buntu', () {
    // `GET /orders` belum tentu mengirim `charge_path`. Kalau dibiarkan
    // kosong, halaman pembayaran menolak membuat tagihan dan pembeli tidak
    // punya cara melunasi sama sekali.
    final co = Order.fromJson(belumBayar).toCheckoutResult();

    expect(co.chargePath, PaymentApi.defaultChargePath);
    expect(co.canCharge, isTrue);
  });

  test('order_id kosong jatuh ke document_number', () {
    final order = Order.fromJson({...belumBayar, 'order_id': ''});
    expect(order.payableOrderId, 'APP1790402093801');
  });

  test('pesanan yang sudah lunas TIDAK diarahkan ke pembayaran', () {
    for (final status in ['app_paid', 'app_ready', 'active']) {
      final order = Order.fromJson({...belumBayar, 'status': status, 'id': 208569});
      expect(order.isAwaitingPayment, isFalse, reason: status);
      expect(order.isUsable, isTrue, reason: status);
    }
  });
}
