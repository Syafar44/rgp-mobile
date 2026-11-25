// Kontrak `additionalData` notifikasi OneSignal — mengikuti dokumen backend
// "Push Notification Pesanan via OneSignal", bagian 5:
//
//   { "order_id": 123, "status": "app_ready" }
//
// Aturan pentingnya: ketukan notifikasi hanya boleh membuka halaman status
// pesanan bila ada `order_id` numerik — tanpa itu halamannya pasti kosong.

import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/core/push/push_service.dart';

void main() {
  test('payload resmi backend terbaca utuh', () {
    final p = PushPayload.fromData(
      {'order_id': 123, 'status': 'app_ready'},
      title: 'Pesanan siap diambil',
      body: 'APP1790152222661 · Juanda 1',
    );

    expect(p.orderId, 123);
    expect(p.status, 'app_ready');
    expect(p.isOrder, isTrue);
    expect(p.canOpenOrder, isTrue);
    expect(p.title, 'Pesanan siap diambil');
  });

  test('kedua status yang dikirim server dikenali sebagai pesanan', () {
    for (final status in ['app_paid', 'app_ready']) {
      final p = PushPayload.fromData({'order_id': 208569, 'status': status});
      expect(p.status, status);
      expect(p.isOrder, isTrue, reason: status);
      expect(p.canOpenOrder, isTrue, reason: status);
    }
  });

  test('order_id berupa string tetap terbaca', () {
    final p = PushPayload.fromData({'order_id': '208569'});
    expect(p.orderId, 208569);
    expect(p.canOpenOrder, isTrue);
  });

  test('ejaan kunci lain tetap diterima sebagai cadangan', () {
    expect(PushPayload.fromData({'orders_id': 11}).orderId, 11);
    expect(PushPayload.fromData({'pos_orders_id': 12}).orderId, 12);
    expect(
      PushPayload.fromData({'order_number': 'APP123'}).documentNumber,
      'APP123',
    );
  });

  test('status tanpa order_id → dikenali pesanan, TAPI belum bisa dibuka', () {
    final p = PushPayload.fromData({'status': 'app_ready'});

    expect(p.isOrder, isTrue);
    // Tanpa id numerik, `GET /pos/app/v1/orders/:id` tidak bisa dipanggil —
    // aplikasi mengantar ke daftar Pesanan, bukan ke halaman status kosong.
    expect(p.canOpenOrder, isFalse);
  });

  test('payload kosong atau null tidak membuat aplikasi salah arah', () {
    for (final p in [
      PushPayload.fromData(null),
      PushPayload.fromData(const {}),
    ]) {
      expect(p.isOrder, isFalse);
      expect(p.canOpenOrder, isFalse);
      expect(p.orderId, 0);
    }
  });

  test('order_id tidak masuk akal diperlakukan sebagai tidak ada', () {
    expect(PushPayload.fromData(const {'order_id': 'abc'}).orderId, 0);
    expect(PushPayload.fromData(const {'order_id': null}).orderId, 0);
    expect(PushPayload.fromData(const {'order_id': 0}).canOpenOrder, isFalse);
  });
}
