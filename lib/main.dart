import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/network/dio_client.dart';
import 'core/push/push_service.dart';
import 'core/utils/app_version.dart';
import 'data/auth_store.dart';
import 'data/cart_store.dart';
import 'data/item_swap_store.dart';
import 'data/order_store.dart';
import 'data/outlet_store.dart';
import 'data/push_repository.dart';

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

  // Sesi yang ditolak server (401) memulangkan pembeli ke layar masuk, dari
  // layar mana pun. Tanpa ini ia terjebak pada aplikasi yang tampak masuk
  // tapi setiap aksinya ditolak satu per satu.
  onUnauthenticated = authStore.logout;

  // Muat data lokal HP dulu (sesi login & outlet terpilih) agar tidak ada
  // kedipan dari halaman login saat sesi sebelumnya masih aktif.
  // Keadaan Ganti Item (tiruan) ikut dimuat sebelum pesanan berjalan, supaya
  // bilahnya langsung menampilkan "Perlu tindakan" bila ada.
  await Future.wait([
    authStore.load(),
    outletStore.load(),
    itemSwapStore.load(),
    // Versi terpasang untuk tulisan "Versi Aplikasi" di Profile.
    AppVersion.load(),
  ]);
  // Keranjang ada di server & bersifat per-outlet: muat bila sudah ada outlet
  // terpilih dari sesi sebelumnya. Best-effort (galat ditangani di store).
  await cartStore.syncWithSelectedOutlet();
  // Pesanan berjalan menentukan tampil/tidaknya bilah pesanan di atas navbar.
  if (authStore.isLoggedIn) await orderStore.refresh();

  // Push notification. Dinyalakan setelah sesi dimuat supaya perangkat bisa
  // langsung ditautkan ke akun yang sudah masuk dari sesi sebelumnya.
  await pushService.init();
  pushService.onOpen = handlePushOpen;
  pushService.fetchExternalId = pushRepository.externalId;
  // Notifikasi yang tiba selagi aplikasi terbuka membuat data pesanan basi —
  // segarkan supaya bilah pesanan aktif di atas navbar ikut berubah. Layar
  // daftar & status menyimak `lastForeground` sendiri.
  pushService.lastForeground.addListener(orderStore.refresh);
  _bindPushIdentity();

  runApp(const RotiGembungApp());
}

/// Jaga agar identitas OneSignal selalu mengikuti akun yang sedang masuk.
///
/// Dipasang sekali di sini, bukan disebar di tiap halaman login/daftar/keluar:
/// satu listener menangkap semuanya, jadi tidak ada jalur masuk yang terlewat
/// dan tidak ada perangkat yang tertinggal tertaut ke akun lama.
///
/// Penautan diulang juga tiap aplikasi kembali ke depan, sesuai permintaan
/// dokumen backend: `external_id` dibuat server dan bisa berubah bila kunci di
/// sana diganti, jadi nilai lama tidak boleh dianggap selamanya benar.
void _bindPushIdentity() {
  void sync() {
    if (authStore.isLoggedIn) {
      pushService.linkToBuyer();
    } else {
      pushService.unlink();
    }
  }

  authStore.currentUser.addListener(sync);
  AppLifecycleListener(onResume: sync);
  sync();
}
