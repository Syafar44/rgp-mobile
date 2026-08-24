import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/cart_item.dart';
import 'models/product.dart';

/// Penyimpanan keranjang belanja.
///
/// Sumber kebenaran untuk UI adalah [notifier] (in-memory) agar layar ikut
/// ter-update seketika. Isinya juga dipertahankan ke penyimpanan lokal HP
/// ([SharedPreferences]) sehingga keranjang tidak hilang saat aplikasi ditutup.
/// Operasi penyimpanan bersifat best-effort; kegagalan (mis. plugin belum
/// tersedia saat test) diabaikan agar tidak mengganggu alur.
class CartStore {
  CartStore();

  final ValueNotifier<List<CartItem>> notifier =
      ValueNotifier<List<CartItem>>([]);

  static const String _key = 'cart_v1';

  List<CartItem> get items => notifier.value;

  /// Total jumlah unit di keranjang.
  int get count => items.fold(0, (sum, e) => sum + e.qty);

  /// Total harga seluruh baris.
  int get total => items.fold(0, (sum, e) => sum + e.subtotal);

  bool get isEmpty => items.isEmpty;

  /// Muat keranjang dari penyimpanan lokal. Panggil sekali saat aplikasi start.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      notifier.value = decoded
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Abaikan: plugin belum siap atau data tersimpan tidak valid.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      // Abaikan kegagalan penyimpanan (best-effort).
    }
  }

  /// Tambah [product] ke keranjang. Bila sudah ada, jumlahnya ditambah dan
  /// catatan diperbarui bila [note] diisi.
  void add(Product product, {int qty = 1, String note = ''}) {
    final list = List.of(items);
    final idx = list.indexWhere((e) => e.product.id == product.id);
    if (idx >= 0) {
      final existing = list[idx];
      list[idx] = existing.copyWith(
        qty: existing.qty + qty,
        note: note.isNotEmpty ? note : existing.note,
      );
    } else {
      list.add(CartItem(product: product, qty: qty, note: note));
    }
    notifier.value = list;
    _save();
  }

  /// Setel jumlah baris [productId]. Bila ≤ 0, baris dihapus.
  void setQty(String productId, int qty) {
    final list = List.of(items);
    final idx = list.indexWhere((e) => e.product.id == productId);
    if (idx < 0) return;
    if (qty <= 0) {
      list.removeAt(idx);
    } else {
      list[idx] = list[idx].copyWith(qty: qty);
    }
    notifier.value = list;
    _save();
  }

  void setNote(String productId, String note) {
    final list = List.of(items);
    final idx = list.indexWhere((e) => e.product.id == productId);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(note: note);
    notifier.value = list;
    _save();
  }

  void remove(String productId) => setQty(productId, 0);

  void clear() {
    notifier.value = [];
    _save();
  }
}

/// Instance global keranjang (dummy). Dimuat dari lokal saat `main()`.
final CartStore cartStore = CartStore();
