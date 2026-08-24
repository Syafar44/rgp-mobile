import 'package:flutter/foundation.dart';

import 'dummy/dummy_data.dart';
import 'models/saved_address.dart';

/// Penyimpanan sementara daftar alamat delivery (in-memory).
///
/// Sementara memakai [ValueNotifier] agar UI ikut ter-update saat alamat
/// ditambah/diubah/dihapus. Saat API siap, ganti dengan repository + Dio.
class AddressStore {
  AddressStore(List<SavedAddress> seed)
      : notifier = ValueNotifier<List<SavedAddress>>(List.of(seed));

  final ValueNotifier<List<SavedAddress>> notifier;

  List<SavedAddress> get items => notifier.value;

  void add(SavedAddress address) {
    final list = List.of(items);
    if (address.isPrimary) _clearPrimary(list);
    list.insert(0, address);
    notifier.value = list;
  }

  void update(SavedAddress address) {
    final list = List.of(items);
    final index = list.indexWhere((e) => e.id == address.id);
    if (index < 0) return;
    if (address.isPrimary) _clearPrimary(list);
    list[index] = address;
    notifier.value = list;
  }

  void remove(String id) {
    notifier.value = items.where((e) => e.id != id).toList();
  }

  void _clearPrimary(List<SavedAddress> list) {
    for (var i = 0; i < list.length; i++) {
      if (list[i].isPrimary) list[i] = list[i].copyWith(isPrimary: false);
    }
  }
}

/// Instance global sederhana (dummy). Seed dari [DummyData.seedAddresses].
final AddressStore addressStore = AddressStore(DummyData.seedAddresses);
