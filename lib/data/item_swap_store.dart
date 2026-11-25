import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_features.dart';
import 'models/item_swap.dart';
import 'models/order.dart';

/// Keadaan modul Ganti Item Tidak Tersedia, per pesanan.
///
/// **Tiruan, sampai backend menyediakannya.** Server belum mengenal item habis
/// maupun status `perlu_tindakan`, jadi keadaannya disimpan di sini lalu
/// ditempelkan ke setiap pesanan yang dibaca dari server ([overlay],
/// [overlayList]). Selama kosong — yaitu selalu, pada build rilis, karena
/// simulasinya hanya ada di menu debug — semua pesanan lewat apa adanya.
///
/// Disimpan di HP agar catatan penggantian tetap terlihat di Riwayat setelah
/// aplikasi ditutup.
class ItemSwapStore {
  static const String _kKey = 'item_swap_v1';

  /// Id pesanan tiruan dimulai dari sini — jauh di atas id POS yang wajar,
  /// supaya tidak pernah bertabrakan dengan pesanan asli.
  static const int idTiruanAwal = 990000000;

  final ValueNotifier<Map<int, OrderSwap>> state =
      ValueNotifier<Map<int, OrderSwap>>(const {});

  /// Selalu kosong bila modul dimatikan ([kFiturGantiItem]) — semua
  /// penempelan di bawah lalu meneruskan pesanan apa adanya, sehingga status
  /// `perlu_tindakan` tidak pernah terbentuk.
  // TODO(ganti-item): hapus gate saat modul dirilis
  bool get isEmpty => !kFiturGantiItem || state.value.isEmpty;

  OrderSwap? of(int orderId) => isEmpty ? null : state.value[orderId];

  bool isTiruan(int orderId) => state.value[orderId]?.isTiruan ?? false;

  /// Id untuk pesanan tiruan berikutnya.
  int get idTiruanBerikutnya {
    var id = idTiruanAwal;
    for (final k in state.value.keys) {
      if (k >= id) id = k + 1;
    }
    return id;
  }

  // --- Penempelan -----------------------------------------------------------

  /// [order] dengan keadaan Ganti Item-nya, atau apa adanya bila tidak ada.
  Order overlay(Order order) => of(order.id)?.applyTo(order) ?? order;

  /// Pesanan tiruan dengan id ini, sudah ditempeli. Null bila bukan tiruan.
  Order? pesananTiruan(int orderId) {
    if (isEmpty) return null;
    final swap = of(orderId);
    final json = swap?.pesananTiruan;
    if (swap == null || json == null) return null;
    final order = Order.fromJson({
      ...json,
      // Status tiruan dikendalikan dari sini, bukan dari JSON tersimpan.
      'status': swap.diserahkan ? 'active' : 'app_paid',
      'status_label': swap.diserahkan ? 'Selesai' : 'Sedang disiapkan',
    });
    return swap.applyTo(order);
  }

  /// Tempelkan ke sehalaman daftar, dan sisipkan pesanan tiruan yang sesuai
  /// tab ([riwayat] = tab Riwayat) di halaman pertama.
  ///
  /// Idempoten: pesanan tiruan yang sudah ada di [orders] dibuang dulu lalu
  /// disisipkan ulang, jadi tidak pernah muncul dua kali.
  List<Order> overlayList(
    List<Order> orders, {
    required bool riwayat,
    bool halamanPertama = true,
  }) {
    if (isEmpty) return orders;
    final tiruan = <Order>[
      if (halamanPertama)
        for (final s in state.value.values)
          if (s.isTiruan && s.diserahkan == riwayat) ?pesananTiruan(s.orderId),
    ];
    return [
      ...tiruan,
      for (final o in orders)
        if (!isTiruan(o.id)) overlay(o),
    ];
  }

  OrderPage overlayPage(OrderPage page, {required bool riwayat}) {
    if (isEmpty) return page;
    return OrderPage(
      orders: overlayList(
        page.orders,
        riwayat: riwayat,
        halamanPertama: page.page <= 1,
      ),
      page: page.page,
      totalPage: page.totalPage,
    );
  }

  // --- Perubahan ------------------------------------------------------------

  /// Tandai [habis] pada pesanan [order] sebagai tidak tersedia.
  ///
  /// [pesananTiruan] diisi bila pesanannya buatan simulasi (bentuk respons
  /// server), null bila pesanan asli.
  Future<void> tandaiHabis(
    Order order,
    List<OrderLine> habis, {
    Map<String, dynamic>? pesananTiruan,
  }) async {
    // TODO(ganti-item): hapus gate saat modul dirilis
    if (!kFiturGantiItem) return;
    _set(
      order.id,
      OrderSwap(
        orderId: order.id,
        documentNumber: order.documentNumber,
        items: [for (final l in habis) ItemSwap.dariBaris(l)],
        pesananTiruan: pesananTiruan,
      ),
    );
    await _save();
  }

  /// Simpan keputusan pembeli untuk satu item.
  Future<void> selesaikan(int orderId, ItemSwap updated) async {
    final swap = of(orderId);
    if (swap == null) return;
    _set(orderId, swap.ganti(updated));
    await _save();
  }

  /// Khusus pesanan tiruan: anggap sudah diserahkan kasir → pindah ke Riwayat.
  Future<void> serahkan(int orderId) async {
    final swap = of(orderId);
    if (swap == null || !swap.isTiruan) return;
    _set(orderId, swap.serahkan());
    await _save();
  }

  Future<void> hapus(int orderId) async {
    if (!state.value.containsKey(orderId)) return;
    state.value = Map.unmodifiable({...state.value}..remove(orderId));
    await _save();
  }

  /// Kosongkan (dipakai saat pengguna keluar).
  void clear() {
    if (isEmpty) return;
    state.value = const {};
    _save();
  }

  void _set(int orderId, OrderSwap swap) {
    state.value = Map.unmodifiable({...state.value, orderId: swap});
  }

  // --- Penyimpanan ----------------------------------------------------------

  Future<void> load() async {
    // TODO(ganti-item): hapus gate saat modul dirilis
    if (!kFiturGantiItem) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      final map = <int, OrderSwap>{};
      for (final e in list.whereType<Map>()) {
        final swap = OrderSwap.fromJson(e.cast<String, dynamic>());
        if (swap.orderId > 0) map[swap.orderId] = swap;
      }
      state.value = Map.unmodifiable(map);
    } catch (_) {
      // Data rusak/plugin tidak tersedia (test) — mulai kosong.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isEmpty) {
        await prefs.remove(_kKey);
        return;
      }
      await prefs.setString(
        _kKey,
        jsonEncode([for (final s in state.value.values) s.toJson()]),
      );
    } catch (_) {
      // Gagal menyimpan bukan penghalang — keadaan di memori tetap berlaku.
    }
  }
}

/// Instance global siap pakai (sejalan dengan `orderStore`, `cartStore`).
final ItemSwapStore itemSwapStore = ItemSwapStore();
