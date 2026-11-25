// Isi bilah "pesanan berjalan".
//
// Bilah ini menentukan dua hal sekaligus: apakah bilah keranjang tampil, dan
// apakah checkout baru tertahan. Jadi memuat pesanan yang sebenarnya sudah
// tuntas bukan sekadar salah tampilan — pembeli jadi tidak bisa memesan lagi.

import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/data/models/order.dart';
import 'package:roti_gembung_panglima_app/data/order_store.dart';

Order buat(OrderStatus status, {int id = 1}) => Order(
  id: id,
  documentNumber: 'APP$id',
  outletId: 19,
  outletName: 'RGP',
  status: status,
  statusLabel: status.code,
  totalAmount: 3000,
  itemCount: 1,
);

void main() {
  tearDown(orderStore.clear);

  test('pesanan yang belum tuntas tetap dimuat', () {
    orderStore.setActive([
      buat(OrderStatus.pending, id: 1),
      buat(OrderStatus.appPending, id: 2),
      buat(OrderStatus.appPaid, id: 3),
      buat(OrderStatus.appReady, id: 4),
    ]);

    expect(orderStore.count, 4);
    expect(orderStore.hasActive, isTrue);
  });

  test('pesanan yang sudah serah terima dibuang', () {
    // `active` berarti kasir sudah menyerahkan pesanannya. Tidak ada lagi
    // yang perlu ditunggu, jadi bilahnya harus hilang — dan bilah keranjang
    // boleh muncul lagi.
    orderStore.setActive([buat(OrderStatus.active)]);

    expect(orderStore.active.value, isEmpty);
    expect(orderStore.hasActive, isFalse);
  });

  test('pesanan batal & status tak dikenal ikut dibuang', () {
    orderStore.setActive([
      buat(OrderStatus.appCancelled, id: 1),
      buat(OrderStatus.voided, id: 2),
      buat(OrderStatus.unknown, id: 3),
    ]);

    expect(orderStore.active.value, isEmpty);
  });

  test('campuran: hanya yang berjalan yang tersisa', () {
    orderStore.setActive([
      buat(OrderStatus.active, id: 1),
      buat(OrderStatus.pending, id: 2),
      buat(OrderStatus.appCancelled, id: 3),
    ]);

    expect(orderStore.count, 1);
    expect(orderStore.latest!.id, 2);
  });
}
