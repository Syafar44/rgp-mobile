import 'package:flutter/material.dart';

import 'app.dart';
import 'data/cart_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Muat keranjang yang tersimpan di lokal HP (best-effort, tak memblokir UI).
  cartStore.load();
  runApp(const RotiGembungApp());
}
