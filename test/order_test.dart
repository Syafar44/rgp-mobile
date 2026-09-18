// Kontrak parsing checkout & pesanan — memakai contoh respons dari dokumen
// "API Aplikasi Customer — Outlet, Menu, Keranjang & Pesanan".

import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/core/utils/wita.dart';
import 'package:roti_gembung_panglima_app/data/models/order.dart';

void main() {
  group('Order.fromJson (detail / hasil checkout)', () {
    const detail = {
      'id': 188003,
      'document_number': 'APP1789358354929',
      'outlet_id': 19,
      'outlet_name': 'Roti Gembung Panglima - Juanda 1',
      'status': 'app_pending',
      'status_label': 'Menunggu diambil',
      'total_amount': 69000,
      'item_count': 5,
      'pickup_at': '2026-09-14T15:00:00+08:00',
      'created_at': '2026-09-14T11:59:15+08:00',
      'keterangan': 'Tolong dipisah bungkusnya',
      'subtotal_amount': 69000,
      'discount_amount': 0,
      'lines': [
        {
          'menu_id': 49,
          'title': 'Bakpia Basah Cokelat',
          'quantity': 3,
          'price': 3000,
          'subtotal': 9000,
        },
        {
          'menu_id': 150,
          'title': 'Paket Hemat 3',
          'quantity': 2,
          'price': 30000,
          'subtotal': 60000,
          'props': [
            {'menu_id': 101, 'title': 'Roti Coklat', 'quantity': 4},
            {'menu_id': 102, 'title': 'Roti Keju', 'quantity': 2},
          ],
        },
      ],
    };

    test('membaca seluruh field pesanan', () {
      final order = Order.fromJson(detail);

      expect(order.id, 188003);
      expect(order.documentNumber, 'APP1789358354929');
      expect(order.outletId, 19);
      expect(order.outletName, 'Roti Gembung Panglima - Juanda 1');
      expect(order.status, OrderStatus.appPending);
      expect(order.statusLabel, 'Menunggu diambil');
      expect(order.totalAmount, 69000);
      expect(order.itemCount, 5);
      expect(order.keterangan, 'Tolong dipisah bungkusnya');
      expect(order.subtotalAmount, 69000);
      expect(order.discountAmount, 0);
      expect(order.hasLines, isTrue);
      expect(order.lines, hasLength(2));
    });

    test('waktu dibaca sebagai jam dinding WITA, bukan jam perangkat', () {
      final order = Order.fromJson(detail);

      // Apa pun zona waktu perangkat yang menjalankan test, jam ambil tetap
      // 15:00 WITA seperti yang dimaksud outlet.
      expect(order.pickupAt!.hour, 15);
      expect(order.pickupAt!.minute, 0);
      expect(order.pickupAt!.day, 14);
      expect(order.createdAt!.hour, 11);
      expect(order.createdAt!.minute, 59);
    });

    test('paket membawa isi varian dengan qty yang sudah dikali server', () {
      final order = Order.fromJson(detail);
      final paket = order.lines[1];

      expect(paket.isPackage, isTrue);
      expect(paket.quantity, 2);
      // 2 paket × 2 Roti Coklat = 4 (server yang mengalikan).
      expect(paket.props.first.title, 'Roti Coklat');
      expect(paket.props.first.quantity, 4);

      expect(order.lines.first.isPackage, isFalse);
    });
  });

  group('OrderStatus', () {
    test('memetakan kode server ke logika tombol', () {
      expect(OrderStatus.fromCode('app_pending').canCancel, isTrue);
      expect(OrderStatus.fromCode('app_pending').isActive, isTrue);

      // `active` berarti sudah diambil & dibayar — masuk riwayat, tak bisa batal.
      expect(OrderStatus.fromCode('active').canCancel, isFalse);
      expect(OrderStatus.fromCode('active').isDone, isTrue);

      expect(OrderStatus.fromCode('app_cancelled').isCancelled, isTrue);
      expect(OrderStatus.fromCode('voided').isCancelled, isTrue);
    });

    test('status yang belum dikenal tidak membuat crash', () {
      final status = OrderStatus.fromCode('status_baru_dari_backend');
      expect(status, OrderStatus.unknown);
      expect(status.canCancel, isFalse);
      expect(status.isDone, isTrue);
    });
  });

  group('OrderPage.fromResponse (daftar pesanan)', () {
    test('membaca daftar beserta metadata paginasi', () {
      final page = OrderPage.fromResponse({
        'message': 'Success',
        'data': [
          {
            'id': 188003,
            'document_number': 'APP1789358354929',
            'outlet_id': 19,
            'outlet_name': 'Roti Gembung Panglima - Juanda 1',
            'status': 'app_pending',
            'status_label': 'Menunggu diambil',
            'total_amount': 69000,
            'item_count': 5,
            'pickup_at': '2026-09-14T15:00:00+08:00',
            'created_at': '2026-09-14T11:59:15+08:00',
          },
        ],
        'metadata': {
          'total': 1,
          'from': 1,
          'to': 1,
          'page': 1,
          'limit': 10,
          'total_page': 1,
        },
      });

      expect(page.orders, hasLength(1));
      expect(page.page, 1);
      expect(page.totalPage, 1);
      expect(page.hasMore, isFalse);
      // Respons daftar tidak membawa rincian item.
      expect(page.orders.first.hasLines, isFalse);
    });

    test('halaman pertama dari beberapa halaman menandai masih ada lanjutan', () {
      final page = OrderPage.fromResponse({
        'data': <Map<String, dynamic>>[],
        'metadata': {'page': 1, 'total_page': 3},
      });

      expect(page.hasMore, isTrue);
    });
  });

  group('Waktu WITA', () {
    test('jam ambil dikirim dengan offset +08:00', () {
      final pickup = DateTime(2026, 9, 14, 15, 0);
      expect(rfc3339Wita(pickup), '2026-09-14T15:00:00+08:00');
    });

    test('waktu ber-offset lain diubah ke jam dinding WITA', () {
      // 08:00 WIB (+07:00) = 09:00 WITA.
      final wita = parseWita('2026-09-14T08:00:00+07:00');
      expect(wita!.hour, 9);
    });

    test('nilai kosong/ngawur menghasilkan null, bukan exception', () {
      expect(parseWita(null), isNull);
      expect(parseWita(''), isNull);
      expect(parseWita('bukan tanggal'), isNull);
    });
  });
}
