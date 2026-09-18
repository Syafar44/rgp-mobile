import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/outlet.dart';

/// Outlet Panglima yang sedang dipilih — **satu untuk seluruh aplikasi**
/// (dipakai Beranda, Menu, Keranjang). `id`-nya dibutuhkan untuk endpoint menu
/// `GET /pos/app/v1/outlets/:id/menus`.
///
/// Dipertahankan ke lokal HP (SharedPreferences) agar pilihan tak hilang saat
/// aplikasi ditutup. Best-effort; kegagalan penyimpanan diabaikan.
class OutletStore {
  OutletStore();

  final ValueNotifier<Outlet?> selected = ValueNotifier<Outlet?>(null);

  static const String _key = 'selected_outlet_v1';

  Outlet? get outlet => selected.value;

  /// id outlet terpilih (untuk endpoint menu). Null bila belum dipilih.
  int? get outletId => selected.value?.id;

  bool get hasOutlet => selected.value != null;

  void select(Outlet o) {
    selected.value = o;
    _save();
  }

  void clear() {
    selected.value = null;
    _save();
  }

  /// Muat pilihan outlet dari lokal. Panggil sekali saat aplikasi start.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      selected.value = Outlet.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // Abaikan: plugin belum siap atau data tidak valid.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final o = selected.value;
      if (o == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, jsonEncode(o.toJson()));
      }
    } catch (_) {
      // Abaikan kegagalan penyimpanan (best-effort).
    }
  }
}

/// Instance global siap pakai (sejalan dengan `authStore`, `cartStore`).
final OutletStore outletStore = OutletStore();
