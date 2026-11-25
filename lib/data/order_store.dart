import 'package:flutter/foundation.dart';

import 'item_swap_store.dart';
import 'models/order.dart';
import 'order_repository.dart';

/// Pesanan yang sedang berjalan — sumber data bilah "pesanan aktif".
///
/// Isinya `GET /pos/app/v1/orders?status=active`, yaitu pesanan yang sudah
/// dibayar tapi belum diambil. Tidak disimpan lokal: server tetap satu-satunya
/// sumber kebenaran, sama seperti keranjang.
///
/// Dimuat ulang saat aplikasi start, setelah pembayaran berhasil, dan setiap
/// kali tab Pesanan dibuka — jadi bilahnya hilang sendiri begitu pesanan
/// diambil atau dibatalkan.
class OrderStore {
  OrderStore(this._repo, this._swaps) {
    // Keadaan Ganti Item berubah (simulasi, pengganti dipilih) → bilah ikut
    // berubah saat itu juga, tanpa menunggu permintaan ke server.
    _swaps.state.addListener(_terapkan);
  }

  final OrderRepository _repo;
  final ItemSwapStore _swaps;

  /// Potret terakhir dari server, sebelum ditempeli keadaan Ganti Item.
  List<Order> _dariServer = const [];

  final ValueNotifier<List<Order>> active = ValueNotifier<List<Order>>(
    const [],
  );

  /// True selama pemuatan berlangsung (bilah tidak perlu menampilkannya,
  /// tapi berguna agar pemanggilan tidak menumpuk).
  bool _loading = false;

  bool get hasActive => active.value.isNotEmpty;

  int get count => active.value.length;

  /// Pesanan terbaru yang sedang berjalan. Null bila tidak ada.
  Order? get latest => active.value.isEmpty ? null : active.value.first;

  /// Muat ulang daftar pesanan berjalan.
  ///
  /// Galat sengaja ditelan: bilah ini pelengkap, bukan alur utama — kalau
  /// jaringan bermasalah, bilahnya cukup tidak muncul tanpa mengganggu layar
  /// yang sedang dipakai.
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      // Halaman pertama sudah cukup: yang terbaru ada di atas, dan bilah ini
      // hanya menampilkan satu pesanan.
      final page = await _repo.active(page: 1, limit: 10);
      _dariServer = page.orders;
      _terapkan();
    } catch (_) {
      // Biarkan isi sebelumnya apa adanya.
    } finally {
      _loading = false;
    }
  }

  /// Perbarui dari daftar yang sudah terlanjur dimuat layar lain (mis. tab
  /// Pesanan), supaya tidak ada permintaan ganda ke server.
  void setActive(List<Order> orders) {
    _dariServer = orders;
    _terapkan();
  }

  /// Hitung ulang isi bilah dari potret server + keadaan Ganti Item.
  void _terapkan() => active.value = _masihBerjalan(
    _swaps.overlayList(_dariServer, riwayat: false),
  );

  /// Saring hanya pesanan yang benar-benar belum tuntas.
  ///
  /// `GET /orders?status=active` sesekali masih memuat pesanan yang sudah
  /// diserahkan kasir (`active` = serah terima) atau dibatalkan. Bilah pesanan
  /// berjalan tidak boleh memunculkannya: pembeli sudah memegang rotinya,
  /// jadi tidak ada lagi yang perlu ditunggu — dan selama bilah itu tampil,
  /// bilah keranjang ikut tersembunyi dan checkout baru tertahan.
  List<Order> _masihBerjalan(List<Order> orders) =>
      orders.where((o) => o.status.isActive).toList(growable: false);

  /// Kosongkan (dipakai saat pengguna keluar).
  ///
  /// Keadaan Ganti Item ikut dibuang: isinya milik akun yang keluar.
  void clear() {
    _dariServer = const [];
    _swaps.clear();
    active.value = const [];
  }
}

/// Instance global siap pakai (sejalan dengan `cartStore`, `outletStore`).
final OrderStore orderStore = OrderStore(orderRepository, itemSwapStore);
