import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'data/auth_store.dart';
import 'data/cart_store.dart';
import 'data/outlet_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Base URL & API key (lihat `.env` / `.env.example`). Bila file tidak ada,
  // aplikasi tetap jalan — fitur yang butuh API yang memberi pesan jelas
  // (lihat `Env.isConfigured`).
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Gagal memuat .env: $e');
  }

  // Muat data lokal HP dulu (sesi login & outlet terpilih) agar tidak ada
  // kedipan dari halaman login saat sesi sebelumnya masih aktif.
  await Future.wait([authStore.load(), outletStore.load()]);
  // Keranjang ada di server & bersifat per-outlet: muat bila sudah ada outlet
  // terpilih dari sesi sebelumnya. Best-effort (galat ditangani di store).
  await cartStore.syncWithSelectedOutlet();
  runApp(const RotiGembungApp());
}
