// Rincian biaya pada detail pesanan (`charges`).
//
// Memakai respons nyata `GET /pos/app/v1/orders/214359` (log 28 Sep 2026).
// Angka yang tampil di layar harus berasal dari sini, bukan dihitung ulang
// aplikasi: tarif gateway hanya diketahui server dan berubah per metode.

import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/data/models/order.dart';

void main() {
  const respons = {
    'id': 214359,
    'document_number': 'APP1790557105494',
    'outlet_id': 19,
    'outlet_name': 'Roti Gembung Panglima - Juanda 1',
    'status': 'app_ready',
    'status_label': 'Siap diambil',
    'total_amount': 3000,
    'item_count': 1,
    'subtotal_amount': 3000,
    'discount_amount': 0,
    'charges': {
      'subtotal': 3000,
      'items': [
        {
          'charge_type': 'PAYMENT_FEE',
          'label': 'Biaya QRIS (0,9% + PPN 11%)',
          'amount': 30,
          'bearer': 'CUSTOMER',
        },
      ],
      'paid_by_customer': 3030,
    },
  };

  test('subtotal, biaya, dan total terbaca dari `charges`', () {
    final order = Order.fromJson(respons);

    expect(order.charges, isNotNull);
    expect(order.displaySubtotal, 3000);
    expect(order.displayTotal, 3030);

    final biaya = order.charges!.tagihanPembeli;
    expect(biaya, hasLength(1));
    expect(biaya.first.label, 'Biaya QRIS (0,9% + PPN 11%)');
    expect(biaya.first.amount, 30);
    expect(biaya.first.chargeType, 'PAYMENT_FEE');
  });

  test('total dibayar BUKAN `total_amount`', () {
    // `total_amount` adalah nilai pesanan di POS (3.000) dan belum memuat
    // biaya gateway. Memakainya sebagai total tagihan berarti menampilkan
    // angka yang lebih kecil dari yang benar-benar dipotong dari pembeli.
    final order = Order.fromJson(respons);

    expect(order.totalAmount, 3000);
    expect(order.displayTotal, isNot(order.totalAmount));
    expect(order.displayTotal, 3030);
  });

  test('rinciannya berjumlah pas — subtotal + biaya = total', () {
    final order = Order.fromJson(respons);
    final jumlahBiaya = order.charges!.tagihanPembeli.fold<int>(
      0,
      (a, b) => a + b.amount,
    );

    expect(order.displaySubtotal + jumlahBiaya, order.displayTotal);
  });

  test('biaya yang ditanggung outlet tidak masuk rincian pembeli', () {
    // Kalau ikut ditampilkan, penjumlahannya tidak lagi cocok dengan
    // `paid_by_customer` dan terbaca seperti salah hitung.
    final order = Order.fromJson({
      ...respons,
      'charges': {
        'subtotal': 3000,
        'items': [
          {'label': 'Biaya QRIS', 'amount': 30, 'bearer': 'CUSTOMER'},
          {'label': 'Biaya merchant', 'amount': 500, 'bearer': 'MERCHANT'},
        ],
        'paid_by_customer': 3030,
      },
    });

    final biaya = order.charges!.tagihanPembeli;
    expect(biaya, hasLength(1));
    expect(biaya.first.label, 'Biaya QRIS');
    expect(order.displaySubtotal + biaya.first.amount, order.displayTotal);
  });

  group('daftar pesanan (`amount_fee`)', () {
    // Respons nyata `GET /pos/app/v1/orders?status=active` setelah backend
    // menambahkan biaya ke daftar. Bentuknya ringkas — satu angka
    // `amount_fee`, bukan objek `charges` seperti di detail.
    const dariDaftar = {
      'id': 0,
      'document_number': 'APP1790563200123',
      'outlet_id': 12,
      'outlet_name': 'Outlet Panakkukang',
      'status': 'menunggu_pembayaran',
      'status_label': 'Menunggu pembayaran',
      'total_amount': 16000,
      'amount_fee': 160,
      'item_count': 2,
      'order_id': 'APP1790563200123',
      'payment_method': 'qris',
      'provider': 'midtrans',
    };

    test('total yang ditampilkan = nilai pesanan + biaya', () {
      final order = Order.fromJson(dariDaftar);

      // 160 itu persis 0,9% dari 16.000 ditambah PPN 11% — bukti bahwa
      // 16.000 adalah dasarnya, bukan hasil akhirnya.
      expect(order.totalAmount, 16000);
      expect(order.amountFee, 160);
      expect(order.displayFee, 160);
      expect(order.displayTotal, 16160);
    });

    test('`total_amount` sendirian bukan total tagihan', () {
      final order = Order.fromJson(dariDaftar);
      expect(order.displayTotal, isNot(order.totalAmount));
    });

    test('pesanan lunas di daftar dihitung sama', () {
      final order = Order.fromJson({
        ...dariDaftar,
        'id': 4521,
        'status': 'app_paid',
        'status_label': 'Lunas, sedang disiapkan',
      });

      expect(order.status, OrderStatus.appPaid);
      expect(order.displayTotal, 16160);
    });

    test('rincian `charges` menang atas `amount_fee` bila keduanya ada', () {
      // Detail pesanan membawa rincian lengkap; kalau suatu saat server
      // mengirim keduanya, yang dipakai adalah yang lebih rinci — dan
      // biayanya tidak boleh terhitung dua kali.
      final order = Order.fromJson({
        ...dariDaftar,
        'amount_fee': 160,
        'charges': {
          'subtotal': 16000,
          'items': [
            {'label': 'Biaya QRIS', 'amount': 160, 'bearer': 'CUSTOMER'},
          ],
          'paid_by_customer': 16160,
        },
      });

      expect(order.displayFee, 160);
      expect(order.displayTotal, 16160);
    });

    test('tanpa `amount_fee`, total tetap nilai pesanan apa adanya', () {
      final order = Order.fromJson({
        ...dariDaftar,
        'amount_fee': null,
      });

      expect(order.displayFee, 0);
      expect(order.displayTotal, 16000);
    });
  });

  test('jumlah biaya siap dipakai kartu di daftar pesanan', () {
    final order = Order.fromJson(respons);
    expect(order.displayFee, 30);
  });

  test('respons tanpa `charges` tetap menampilkan angka yang masuk akal', () {
    // Daftar pesanan belum mengirim `charges`.
    final order = Order.fromJson({
      'id': 1,
      'document_number': 'APP1',
      'status': 'app_paid',
      'total_amount': 3000,
      'subtotal_amount': 3000,
      'item_count': 1,
    });

    expect(order.charges, isNull);
    expect(order.displaySubtotal, 3000);
    expect(order.displayTotal, 3000);
    // 0 → kartu di daftar pesanan menyembunyikan baris "Termasuk biaya",
    // bukan menampilkan "Rp 0".
    expect(order.displayFee, 0);
  });

  test('subtotal_amount kosong jatuh ke total_amount', () {
    final order = Order.fromJson({
      'id': 1,
      'document_number': 'APP1',
      'status': 'app_paid',
      'total_amount': 7500,
      'item_count': 1,
    });

    expect(order.displaySubtotal, 7500);
  });
}
