// Kontrak parsing `GET /payment/api/v2/payment-methods` — memakai respons
// nyata dari server (diverifikasi lewat curl, HTTP 200).

import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/data/models/payment_method.dart';

void main() {
  const qris = {
    'id': 5,
    'title': 'QRIS',
    'value': 'qris',
    'type': 'qris',
    'provider': 'sumopod',
    'file': '',
    'addons': 300,
    'percentage': 0.7,
  };

  test('membaca seluruh field metode pembayaran', () {
    final m = PaymentMethod.fromJson(qris);

    expect(m.id, 5);
    expect(m.title, 'QRIS');
    expect(m.value, 'qris');
    expect(m.type, 'qris');
    expect(m.provider, 'sumopod');
    expect(m.addons, 300);
    expect(m.percentage, 0.7);
    // `file` kosong → UI memakai ikon bawaan, bukan gambar rusak.
    expect(m.hasLogo, isFalse);
    expect(m.hasFee, isTrue);
  });

  test('biaya = (tetap + persentase) + pajak', () {
    final m = PaymentMethod.fromJson(qris);

    // 100.000 × 0,7% = 700, + tetap 300 = 1.000; tanpa pajak tetap 1.000.
    expect(m.feeFor(100000), 1000);
    expect(m.feeFor(69000), 783);
    // Nominal 0 tetap kena biaya tetap saja.
    expect(m.feeFor(0), 300);
  });

  test('pajak atas biaya ikut dihitung — cocok dengan server', () {
    // QRIS Midtrans yang aktif sekarang: 0,9% + pajak 11%.
    final qrisMidtrans = PaymentMethod.fromJson({
      'id': 7,
      'title': 'QRIS DINAMIS MIDTRANS',
      'value': 'qris',
      'type': 'qris',
      'provider': 'midtrans',
      'addons': 0,
      'percentage': 0.9,
      'tax_percentage': 11,
    });

    // 42.000 × 0,9% = 378 → + pajak 11% (41,58) = 419,58 → 420.
    // Angka ini sama persis dengan `fee` dari POST .../calculate.
    expect(qrisMidtrans.feeFor(42000), 420);

    // Virtual Account: biaya tetap 5.000 + pajak 11% = 5.550.
    final va = PaymentMethod.fromJson({
      'id': 3,
      'title': 'BRI Virtual Account',
      'value': 'bri',
      'type': 'bank_transfer',
      'addons': 5000,
      'percentage': 0,
      'tax_percentage': 11,
    });
    expect(va.feeFor(42000), 5550);
  });

  test('metode tanpa biaya ditandai hasFee = false', () {
    final m = PaymentMethod.fromJson({
      'id': 9,
      'title': 'Tunai',
      'value': 'cash',
      'type': 'cash',
      'addons': 0,
      'percentage': 0,
    });

    expect(m.hasFee, isFalse);
    expect(m.feeFor(50000), 0);
  });

  test('field hilang atau bertipe string tidak membuat parsing gagal', () {
    final m = PaymentMethod.fromJson({
      'id': '12',
      'title': 'VA BCA',
      'addons': '2500',
      'percentage': '1.5',
    });

    expect(m.id, 12);
    expect(m.value, '');
    expect(m.type, '');
    expect(m.addons, 2500);
    expect(m.percentage, 1.5);
    expect(m.feeFor(100000), 4000);
  });
}
