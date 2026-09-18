import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import 'cart_repository.dart';
import 'models/cart.dart';
import 'outlet_store.dart';

/// Keranjang **sisi server**, satu untuk seluruh aplikasi (dipakai bilah
/// keranjang, halaman Konfirmasi Pesanan, dan Checkout).
///
/// Sumber kebenaran ada di server: setiap operasi memanggil API dan mengganti
/// [cart] dengan keranjang terbaru dari respons. Keranjang bersifat per-outlet
/// (satu pembeli hanya boleh punya satu keranjang aktif); saat outlet berganti,
/// panggil [loadFor] untuk memuat keranjang outlet tersebut.
///
/// Operasi tulis melempar [ApiException] agar UI bisa menampilkan pesan
/// (mis. `stok_tidak_tersedia`); isi keranjang tidak diubah bila operasi gagal.
class CartStore {
  CartStore(this._repo);

  final CartRepository _repo;

  final ValueNotifier<ServerCart> cart =
      ValueNotifier<ServerCart>(ServerCart.empty());

  /// True selama memuat/mengubah keranjang (untuk indikator di UI).
  final ValueNotifier<bool> loading = ValueNotifier<bool>(false);

  /// Pesan galat pemuatan terakhir (untuk state error di halaman keranjang).
  /// Null bila tidak ada galat.
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  /// Outlet yang keranjangnya sedang dimuat. Null bila belum pernah dimuat.
  int? _outletId;

  List<ServerCartItem> get items => cart.value.items;
  int get count => cart.value.count;
  int get total => cart.value.total;
  bool get isEmpty => cart.value.isEmpty;

  /// Muat keranjang untuk [outletId] dari server (GET). Aman dipanggil ulang.
  Future<void> loadFor(int outletId) async {
    _outletId = outletId;
    loading.value = true;
    error.value = null;
    try {
      cart.value = await _repo.fetch(outletId);
    } catch (e) {
      // Jangan hapus isi yang sedang tampil bila refresh gagal; cukup catat
      // pesan galat agar UI bisa menampilkannya.
      error.value = apiErrorMessage(e, fallback: 'Gagal memuat keranjang.');
    } finally {
      loading.value = false;
    }
  }

  /// Muat keranjang untuk outlet yang sedang dipilih (bila ada). Dipanggil saat
  /// aplikasi start dan setiap kali outlet berpindah.
  Future<void> syncWithSelectedOutlet() async {
    final id = outletStore.outletId;
    if (id == null) {
      _outletId = null;
      cart.value = ServerCart.empty();
      return;
    }
    if (id == _outletId) return;
    await loadFor(id);
  }

  /// Tambah menu ke keranjang outlet ini (POST). Melempar [ApiException] bila
  /// gagal (mis. stok tidak tersedia).
  Future<void> add(
    int outletId, {
    required int menuId,
    int quantity = 1,
    List<Map<String, dynamic>>? props,
  }) async {
    await _mutate(
      outletId,
      () => _repo.add(
        outletId,
        menuId: menuId,
        quantity: quantity,
        props: props,
      ),
    );
  }

  /// Setel jumlah satu baris. Bila ≤ 0, baris dihapus (server tidak menerima
  /// quantity 0).
  Future<void> setQty(int outletId, int cartId, int quantity) async {
    if (quantity <= 0) return remove(outletId, cartId);
    await _mutate(
      outletId,
      () => _repo.updateQty(outletId, cartId, quantity: quantity),
    );
  }

  Future<void> remove(int outletId, int cartId) async {
    await _mutate(outletId, () => _repo.remove(outletId, cartId));
  }

  Future<void> clear(int outletId) async {
    await _mutate(outletId, () => _repo.clear(outletId));
  }

  /// Cek stok sebelum bayar. Melempar [ApiException] bila gagal.
  Future<bool> validate(int outletId) => _repo.validate(outletId);

  Future<void> _mutate(
    int outletId,
    Future<ServerCart> Function() op,
  ) async {
    _outletId = outletId;
    loading.value = true;
    try {
      cart.value = await op();
      error.value = null;
    } finally {
      loading.value = false;
    }
  }
}

/// Instance global siap pakai (sejalan dengan `authStore`, `outletStore`).
final CartStore cartStore = CartStore(cartRepository);
