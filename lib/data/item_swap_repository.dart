import 'dart:math';

import '../core/config/app_features.dart';
import '../core/config/env.dart';
import '../core/network/api_error.dart';
import '../core/utils/app_log.dart';
import 'dummy/dummy_data.dart';
import 'item_swap_store.dart';
import 'menu_repository.dart';
import 'models/item_swap.dart';
import 'models/order.dart';
import 'models/outlet.dart';
import 'models/product.dart';
import 'order_repository.dart';

/// Satu produk yang bisa dipilih sebagai pengganti.
class SwapCandidate {
  const SwapCandidate({required this.product, required this.stok});

  final Product product;

  /// Stok tiruan di outlet pesanan — batas qty yang boleh dipilih.
  final int stok;

  int get menuId => int.tryParse(product.id) ?? 0;

  int get harga => product.effectivePrice;

  SwapPick pick(int quantity) => SwapPick(
    menuId: menuId,
    title: product.name,
    price: harga,
    quantity: quantity,
  );
}

/// Satu kategori di daftar pengganti.
typedef SwapSection = ({String title, List<SwapCandidate> items});

/// Ganti Item Tidak Tersedia.
///
/// **Masih tiruan — belum ada endpoint.** Selama [Env.isItemSwapLive] false,
/// tidak ada permintaan yang dikirim: pilihan pembeli disimpan di
/// [ItemSwapStore], dan daftar pengganti memakai menu asli outlet dengan stok
/// tiruan dari [DummyData.stokTiruan]. Begitu backend siap, cukup isi
/// [kandidat] dan [simpanPengganti] dengan pemanggilan API.
class ItemSwapRepository {
  ItemSwapRepository(this._menus, this._orders, this._store);

  final MenuRepository _menus;
  final OrderRepository _orders;
  final ItemSwapStore _store;

  /// Urutan kategori di daftar pengganti — sama dengan tab Menu
  /// (`pages/menu_page.dart`). Dicocokkan dengan `contains`, jadi "Bakpia"
  /// menampung "Bakpia Basah" maupun "Bakpia Kering".
  static const List<String> kategori = [
    'Roti Gembung',
    'Donat',
    'Pizza',
    'Bakpia',
    'Bolen',
  ];

  /// Jeda tiruan, supaya keadaan memuat di layar ikut teruji.
  static const Duration _jeda = Duration(milliseconds: 500);

  /// Produk yang tersedia di outlet pesanan, dikelompokkan per kategori.
  ///
  /// Item yang habis — termasuk semua item habis di pesanan ini — tidak ikut
  /// tampil. Paket juga tidak: memilih isinya butuh layar tersendiri.
  Future<List<SwapSection>> kandidat(Order order) async {
    _pastikanTiruan();
    final menu = await _menuOutlet(order.outletId);
    final habis = <int>{
      for (final l in order.lines)
        if (l.tidakTersedia) l.menuId,
      for (final i in _store.of(order.id)?.items ?? const <ItemSwap>[])
        i.menuId,
    };

    final perKategori = <String, List<SwapCandidate>>{};
    for (final p in menu) {
      final cat = kategoriDari(p);
      if (cat == null || p.isPackage || p.effectivePrice <= 0) continue;
      final kandidat = SwapCandidate(
        product: p,
        stok: p.available ? DummyData.stokTiruan(order.outletId, p) : 0,
      );
      if (habis.contains(kandidat.menuId) || kandidat.stok <= 0) continue;
      (perKategori[cat] ??= []).add(kandidat);
    }
    return [
      for (final c in kategori)
        if (perKategori[c]?.isNotEmpty ?? false)
          (title: c, items: perKategori[c]!),
    ];
  }

  /// Simpan pengganti untuk [asal]. [selisihDibayar] diisi bila pengganti
  /// lebih mahal dan kekurangannya sudah dilunasi.
  Future<void> simpanPengganti(
    Order order,
    ItemSwap asal,
    List<SwapPick> picks, {
    int selisihDibayar = 0,
  }) async {
    _pastikanTiruan();
    await Future<void>.delayed(_jeda);
    final hasil = asal.diganti(picks, selisihDibayar: selisihDibayar);
    await _store.selesaikan(order.id, hasil);
    AppLog.info(
      'SWAP',
      'pengganti disimpan (TIRUAN) ${order.documentNumber}',
      detail:
          '${hasil.catatan} · nilai ${asal.nilaiAsal} → ${hasil.totalPengganti}'
          ' · selisih ${hasil.selisih} · dibayar $selisihDibayar',
    );
  }

  // --- Simulasi (menu debug) -------------------------------------------------

  /// Tandai [jumlah] item pesanan sebagai habis.
  ///
  /// [target] = pesanan asli yang sudah dibayar; null = buat pesanan tiruan
  /// berisi 3 item di [outlet]. [acak] memilih item secara acak, bukan dari
  /// atas.
  Future<Order> simulasikan({
    Order? target,
    Outlet? outlet,
    int jumlah = 1,
    bool acak = false,
  }) async {
    _pastikanTiruan();
    Order order;
    Map<String, dynamic>? tiruan;
    if (target != null) {
      // Daftar pesanan tidak membawa rincian item — ambil detailnya.
      order = await _orders.detail(target.id);
      if (!order.hasLines) {
        throw const ApiException(
          'Rincian item pesanan ini tidak tersedia, jadi tidak bisa '
          'disimulasikan. Pakai pesanan tiruan.',
        );
      }
    } else {
      final id = _store.idTiruanBerikutnya;
      final outletId = outlet?.id ?? 0;
      tiruan = DummyData.pesananTiruan(
        id: id,
        outletId: outletId,
        outletName: outlet?.name ?? 'Outlet Simulasi',
        isi: await _isiTiruan(outletId),
      );
      order = Order.fromJson(tiruan);
    }

    final baris = [...order.lines];
    if (acak) baris.shuffle(Random());
    final habis = baris.take(jumlah.clamp(1, baris.length)).toList();
    await _store.tandaiHabis(order, habis, pesananTiruan: tiruan);
    AppLog.info(
      'SWAP',
      'simulasi item habis ${order.documentNumber}',
      detail:
          '${tiruan == null ? 'pesanan asli' : 'pesanan tiruan'} · '
          '${habis.map((l) => '${l.title} ×${l.quantity}').join(', ')}',
    );
    return _store.overlay(order);
  }

  /// 3 item dari menu asli outlet (kategori berbeda bila bisa), atau isi
  /// bawaan [DummyData.isiPesananTiruan] bila menunya tidak tersedia.
  Future<List<({Product product, int qty})>> _isiTiruan(int outletId) async {
    final menu = outletId > 0 ? await _menuOutlet(outletId) : const <Product>[];
    if (identical(menu, DummyData.katalogCadangan) || menu.isEmpty) {
      return DummyData.isiPesananTiruan;
    }
    final layak = [
      for (final p in menu)
        if (kategoriDari(p) != null &&
            !p.isPackage &&
            p.effectivePrice > 0 &&
            p.available &&
            DummyData.stokTiruan(outletId, p) > 0)
          p,
    ];
    final dipilih = <Product>[];
    final kategoriTerpakai = <String>{};
    for (final p in layak) {
      if (kategoriTerpakai.add(kategoriDari(p)!)) dipilih.add(p);
      if (dipilih.length == 3) break;
    }
    for (final p in layak) {
      if (dipilih.length == 3) break;
      if (!dipilih.contains(p)) dipilih.add(p);
    }
    if (dipilih.length < 3) return DummyData.isiPesananTiruan;
    const qty = [2, 1, 1];
    return [for (var i = 0; i < 3; i++) (product: dipilih[i], qty: qty[i])];
  }

  /// Menu outlet, atau [DummyData.katalogCadangan] bila tidak bisa dimuat.
  Future<List<Product>> _menuOutlet(int outletId) async {
    try {
      final menu = await _menus.outletMenus(outletId);
      if (menu.isNotEmpty) return menu;
    } catch (e) {
      AppLog.warn(
        'SWAP',
        'menu outlet $outletId gagal dimuat — pakai katalog cadangan',
        detail: '$e',
      );
    }
    return DummyData.katalogCadangan;
  }

  /// Kategori [p] di antara [kategori]. Null bila di luar daftar.
  static String? kategoriDari(Product p) {
    final cat = p.category.trim().toLowerCase();
    for (final c in kategori) {
      if (cat.contains(c.toLowerCase())) return c;
    }
    if (cat.contains('donut')) return 'Donat';
    return null;
  }

  void _pastikanTiruan() {
    // TODO(ganti-item): hapus gate saat modul dirilis
    if (!kFiturGantiItem) {
      throw const ApiException('Fitur ini belum tersedia.');
    }
    if (!Env.isItemSwapLive) return;
    // Jujur ketimbang diam-diam menyimpan di HP: begitu flag ini dinyalakan,
    // pembeli mengira pilihannya sampai ke outlet.
    throw const ApiException(
      'Ganti item lewat server belum didukung versi aplikasi ini.',
    );
  }
}

/// Instance global siap pakai.
final ItemSwapRepository itemSwapRepository = ItemSwapRepository(
  menuRepository,
  orderRepository,
  itemSwapStore,
);
