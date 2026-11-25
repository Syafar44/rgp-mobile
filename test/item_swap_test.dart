// Ganti Item Tidak Tersedia (tiruan).
//
// Pesanan sudah dibayar, lalu outlet kehabisan satu atau lebih itemnya.
// Pembeli memilih pengganti minimal senilai item itu (refund belum ada) —
// sama dikonfirmasi langsung, lebih dibayar selisihnya — dan pesanan baru
// lanjut disiapkan setelah semua item diganti.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:roti_gembung_panglima_app/core/config/app_features.dart';
import 'package:roti_gembung_panglima_app/data/dummy/dummy_data.dart';
import 'package:roti_gembung_panglima_app/data/item_swap_repository.dart';
import 'package:roti_gembung_panglima_app/data/item_swap_store.dart';
import 'package:roti_gembung_panglima_app/data/models/item_swap.dart';
import 'package:roti_gembung_panglima_app/data/models/order.dart';
import 'package:roti_gembung_panglima_app/data/models/product.dart';
import 'package:roti_gembung_panglima_app/data/order_store.dart';
import 'package:roti_gembung_panglima_app/pages/item_swap_page.dart';
import 'package:roti_gembung_panglima_app/widgets/active_order_bar.dart';

/// Pesanan tiruan bawaan: Donat Coklat ×2 (Rp16.000), Roti Gembung Coklat ×1,
/// Bakpia Kacang Hijau ×2.
Map<String, dynamic> _json(int id) => DummyData.pesananTiruan(
  id: id,
  outletId: 19,
  outletName: 'RGP Test Outlet',
  isi: DummyData.isiPesananTiruan,
);

SwapPick _pick(String id, int qty) {
  final p = DummyData.katalogCadangan.firstWhere((p) => p.id == id);
  return SwapPick(
    menuId: int.parse(p.id),
    title: p.name,
    price: p.price,
    quantity: qty,
  );
}

/// Simulasikan item habis pada pesanan tiruan baru; kembalikan pesanannya.
Future<Order> _simulasi({int jumlah = 1}) async {
  final json = _json(itemSwapStore.idTiruanBerikutnya);
  final order = Order.fromJson(json);
  await itemSwapStore.tandaiHabis(
    order,
    order.lines.take(jumlah).toList(),
    pesananTiruan: json,
  );
  return itemSwapStore.pesananTiruan(order.id)!;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(orderStore.clear);

  // Build profile/rilis: `kFiturGantiItem` mati. Jalankan dengan
  // `flutter test --dart-define=FITUR_GANTI_ITEM=false` untuk memeriksanya.
  if (!kFiturGantiItem) {
    _modulDimatikan();
    return;
  }

  group('hitungan selisih', () {
    const donat = ItemSwap(
      menuId: 9201,
      title: 'Donat Coklat',
      quantity: 2,
      nilaiAsal: 16000,
    );

    test('sama: tidak ada yang dibayar', () {
      final hasil = donat.diganti([_pick('9501', 2)]); // Bolen Keju ×2
      expect(hasil.totalPengganti, 16000);
      expect(hasil.selisih, 0);
    });

    test('kurang: selisih negatif', () {
      // Bakpia Coklat ×2 — halaman menahan konfirmasi pada keadaan ini.
      expect(hitungSelisih(16000, 10000), -6000);
    });

    test('lebih: selisihnya yang dibayar', () {
      final hasil = donat.diganti([
        _pick('9301', 1),
      ], selisihDibayar: 2000); // Pizza Mini Sosis
      expect(hasil.selisih, 2000);
      expect(hasil.selisihDibayar, 2000);
    });

    test('lebih dari satu pengganti dijumlahkan', () {
      final hasil = donat.diganti([_pick('9402', 1), _pick('9501', 1)]);
      expect(hasil.totalPengganti, 13000);
      expect(hasil.catatan, contains('Bakpia Coklat ×1, Bolen Keju ×1'));
    });

    test('catatan riwayat', () {
      expect(
        donat.diganti([_pick('9501', 2)]).catatan,
        'Donat Coklat ×2 → diganti Bolen Keju ×2',
      );
    });
  });

  group('status pesanan', () {
    test('item habis → perlu tindakan; selesai → lanjut disiapkan', () async {
      final order = await _simulasi();
      expect(order.status, OrderStatus.perluTindakan);
      expect(order.status.isActive, isTrue);
      expect(order.status.canCancel, isFalse);
      expect(order.lines.first.menungguTindakan, isTrue);
      expect(order.lines[1].tidakTersedia, isFalse);

      final asal = itemSwapStore.of(order.id)!.items.single;
      await itemSwapStore.selesaikan(
        order.id,
        asal.diganti([_pick('9501', 2)]),
      );

      final sesudah = itemSwapStore.pesananTiruan(order.id)!;
      expect(sesudah.status, OrderStatus.appPaid);
      expect(sesudah.lines.first.sudahDiselesaikan, isTrue);
      expect(sesudah.lines.first.pengganti.single.title, 'Bolen Keju');
    });

    test('dua item habis diselesaikan satu per satu', () async {
      final order = await _simulasi(jumlah: 2);
      final swap = itemSwapStore.of(order.id)!;
      expect(swap.belumSelesai, 2);

      await itemSwapStore.selesaikan(
        order.id,
        swap.items[0].diganti([_pick('9501', 2)]),
      );
      expect(
        itemSwapStore.pesananTiruan(order.id)!.status,
        OrderStatus.perluTindakan,
        reason: 'masih ada satu item yang belum dipilih',
      );

      await itemSwapStore.selesaikan(
        order.id,
        swap.items[1].diganti([_pick('9103', 1)]),
      );
      expect(
        itemSwapStore.pesananTiruan(order.id)!.status,
        OrderStatus.appPaid,
      );
    });

    test('pesanan asli dari server ikut ditempeli', () async {
      const asli = Order(
        id: 208569,
        documentNumber: 'APP1',
        outletId: 19,
        outletName: 'RGP',
        status: OrderStatus.appPaid,
        statusLabel: 'Sedang disiapkan',
        totalAmount: 16000,
        itemCount: 2,
        lines: [
          OrderLine(
            menuId: 586,
            title: 'Roti',
            quantity: 2,
            price: 8000,
            subtotal: 16000,
          ),
        ],
      );
      await itemSwapStore.tandaiHabis(asli, asli.lines);

      final hasil = itemSwapStore.overlay(asli);
      expect(hasil.status, OrderStatus.perluTindakan);
      // Idempoten: daftar yang sama bisa lewat repository lalu store.
      expect(itemSwapStore.overlay(hasil).lines.single.tidakTersedia, isTrue);
    });

    test('pesanan yang sudah diserahkan tidak diubah statusnya', () {
      const swap = OrderSwap(
        orderId: 1,
        documentNumber: 'APP1',
        items: [
          ItemSwap(menuId: 1, title: 'Roti', quantity: 1, nilaiAsal: 8000),
        ],
      );
      const selesai = Order(
        id: 1,
        documentNumber: 'APP1',
        outletId: 19,
        outletName: 'RGP',
        status: OrderStatus.active,
        statusLabel: 'Selesai',
        totalAmount: 8000,
        itemCount: 1,
      );
      expect(swap.applyTo(selesai).status, OrderStatus.active);
    });
  });

  group('bilah & riwayat', () {
    test('pesanan tiruan masuk bilah pesanan berjalan tepat sekali', () async {
      final order = await _simulasi();
      expect(orderStore.active.value.map((o) => o.id), [order.id]);
      expect(orderStore.latest!.status.needsAction, isTrue);

      // Daftar yang sudah memuatnya diteruskan lagi — tidak boleh dobel.
      orderStore.setActive(orderStore.active.value);
      expect(orderStore.count, 1);
    });

    test('diserahkan → pindah ke Riwayat beserta catatannya', () async {
      final order = await _simulasi();
      final asal = itemSwapStore.of(order.id)!.items.single;
      await itemSwapStore.selesaikan(
        order.id,
        asal.diganti([_pick('9501', 2)]),
      );
      await itemSwapStore.serahkan(order.id);

      expect(orderStore.hasActive, isFalse);
      final riwayat = itemSwapStore.overlayList(const [], riwayat: true);
      expect(riwayat.single.status, OrderStatus.active);
      expect(
        itemSwapStore.of(order.id)!.selesaiSaja.single.catatan,
        'Donat Coklat ×2 → diganti Bolen Keju ×2',
      );
    });

    test('keluar akun membuang simulasi', () async {
      await _simulasi();
      orderStore.clear();
      expect(itemSwapStore.isEmpty, isTrue);
    });
  });

  group('kandidat pengganti', () {
    test('tanpa server: katalog cadangan, tanpa item habis', () async {
      final order = await _simulasi();
      final sections = await itemSwapRepository.kandidat(order);

      expect(sections.map((s) => s.title), [
        'Roti Gembung',
        'Donat',
        'Pizza',
        'Bakpia',
        'Bolen',
      ]);
      final ids = [
        for (final s in sections)
          for (final c in s.items) c.product.id,
      ];
      expect(ids, isNot(contains('9201')), reason: 'item yang habis dipesan');
      expect(ids, isNot(contains('9202')), reason: 'stok tiruannya 0');
    });

    test('stok tiruan tetap sama setiap dibaca', () {
      const p = Product(
        id: '586',
        name: 'Roti Gembung',
        category: 'Roti Gembung',
        price: 8000,
        description: '',
      );
      final stok = DummyData.stokTiruan(19, p);
      expect(stok, inInclusiveRange(0, 12));
      expect(DummyData.stokTiruan(19, p), stok);
    });
  });

  group('halaman Pilih Pengganti', () {
    Future<Order> buka(WidgetTester tester) async {
      final order = await tester.runAsync(_simulasi);
      final asal = itemSwapStore.of(order!.id)!.items.single;
      await tester.pumpWidget(
        MaterialApp(
          home: ItemSwapPage(order: order, asal: asal),
        ),
      );
      await tester.pumpAndSettle();
      return order;
    }

    Future<void> pilih(WidgetTester tester, String nama, {int kali = 1}) async {
      // Daftarnya dibangun malas — gulir dulu sampai produknya terbangun.
      await tester.scrollUntilVisible(
        find.text(nama),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final tile = find
          .ancestor(of: find.text(nama), matching: find.byType(Row))
          .first;
      // `scrollUntilVisible` berhenti begitu sebagian tile terlihat — pastikan
      // utuh supaya ketukannya tidak jatuh di luar layar.
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: tile, matching: find.text('Pilih')));
      await tester.pump();
      for (var i = 1; i < kali; i++) {
        await tester.tap(
          find.descendant(of: tile, matching: find.byIcon(Icons.add)),
        );
        await tester.pump();
      }
    }

    testWidgets('tombol mengikuti selisih', (tester) async {
      await buka(tester);
      expect(find.text('Donat Coklat ×2'), findsOneWidget);
      expect(find.text('Pilih produk pengganti'), findsOneWidget);

      // Refund belum ada, jadi tidak ditawarkan sama sekali.
      expect(find.textContaining('Refund'), findsNothing);

      await pilih(tester, 'Bakpia Coklat', kali: 2); // 10.000 < 16.000
      expect(find.text('Tambah Rp 6.000 lagi'), findsOneWidget);
      expect(
        find.text(
          'Pengganti minimal senilai item yang dibayar. Tambah Rp 6.000 lagi.',
        ),
        findsOneWidget,
      );
      final tombol = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Tambah Rp 6.000 lagi'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(tombol.onPressed, isNull, reason: 'belum senilai → terkunci');

      await pilih(tester, 'Bolen Keju'); // +8.000 → 18.000 > 16.000
      expect(find.text('Bayar Selisih Rp 2.000'), findsOneWidget);
    });

    testWidgets('selisih sama → ringkasan → tersimpan', (tester) async {
      final order = await buka(tester);
      await pilih(tester, 'Bolen Keju', kali: 2);
      expect(find.text('Konfirmasi Pengganti'), findsOneWidget);

      await tester.tap(find.text('Konfirmasi Pengganti'));
      await tester.pumpAndSettle();
      expect(find.text('Periksa Penggantian'), findsOneWidget);

      await tester.tap(find.text('Simpan Pengganti'));
      await tester.pumpAndSettle();

      final swap = itemSwapStore.of(order.id)!;
      expect(swap.semuaSelesai, isTrue);
      expect(
        swap.items.single.catatan,
        'Donat Coklat ×2 → diganti Bolen Keju ×2',
      );
    });

    testWidgets('selisih lebih → bayar lewat halaman Pembayaran', (
      tester,
    ) async {
      final order = await buka(tester);
      await pilih(tester, 'Pizza Mini Sosis'); // 18.000 > 16.000
      await tester.tap(find.text('Bayar Selisih Rp 2.000'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lanjut Bayar Rp 2.000'));

      // Penjaga jaringan + tagihan tiruan. Halaman Pembayaran punya timer
      // berkala, jadi tidak bisa `pumpAndSettle`.
      for (
        var i = 0;
        i < 20 && find.text('Lanjutkan Bayar').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('Siap Melakukan Pembayaran'), findsOneWidget);
      await tester.tap(find.text('Lanjutkan Bayar'));
      await tester.pump(const Duration(milliseconds: 300));

      // Pengganti belum tersimpan sebelum lunas.
      expect(itemSwapStore.of(order.id)!.semuaSelesai, isFalse);

      await tester.scrollUntilVisible(
        find.text('Simulasi lunas'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Simulasi lunas'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));

      final asal = itemSwapStore.of(order.id)!.items.single;
      expect(asal.penyelesaian, SwapResolution.diganti);
      expect(asal.selisihDibayar, 2000);
    });
  });

  testWidgets('bilah pesanan berjalan: "Perlu tindakan"', (tester) async {
    await tester.runAsync(_simulasi);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ActiveOrderBar())),
    );
    expect(find.text('Perlu tindakan'), findsOneWidget);
    expect(find.textContaining('1 item tidak tersedia'), findsOneWidget);
    expect(find.text('Pilih'), findsOneWidget);
  });
}

/// Modul dimatikan: aplikasi harus berperilaku persis seperti sebelum modul
/// ada — tidak ada status `perlu_tindakan`, tidak ada simulasi.
void _modulDimatikan() {
  test('status perlu_tindakan tidak pernah dihasilkan', () {
    expect(OrderStatus.fromCode('perlu_tindakan'), OrderStatus.unknown);
  });

  test('menandai item habis tidak berpengaruh', () async {
    final json = _json(ItemSwapStore.idTiruanAwal);
    final order = Order.fromJson(json);
    await itemSwapStore.tandaiHabis(order, order.lines, pesananTiruan: json);

    expect(itemSwapStore.isEmpty, isTrue);
    expect(itemSwapStore.pesananTiruan(order.id), isNull);
    expect(itemSwapStore.overlay(order).status, OrderStatus.appPaid);
    expect(orderStore.hasActive, isFalse);
  });

  test('simulasi & daftar pengganti ditolak', () async {
    await expectLater(itemSwapRepository.simulasikan(), throwsException);
    final order = Order.fromJson(_json(ItemSwapStore.idTiruanAwal));
    await expectLater(itemSwapRepository.kandidat(order), throwsException);
  });

  testWidgets('bilah pesanan berjalan tanpa "Perlu tindakan"', (tester) async {
    orderStore.setActive([Order.fromJson(_json(ItemSwapStore.idTiruanAwal))]);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ActiveOrderBar())),
    );
    expect(find.text('Perlu tindakan'), findsNothing);
    expect(find.text('Pesanan sedang diproses'), findsOneWidget);
  });
}
