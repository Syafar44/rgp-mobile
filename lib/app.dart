import 'package:flutter/material.dart';

import 'core/push/push_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_log.dart';
import 'data/auth_store.dart';
import 'data/models/user_account.dart';
import 'data/notifiers.dart';
import 'pages/auth/login_landing_page.dart';
import 'pages/order_status_page.dart';
import 'widget_tree.dart';
import 'widgets/app_update_gate.dart';

/// Navigator aplikasi, dipakai dari luar pohon widget — saat ini oleh ketukan
/// notifikasi, yang datang dari SDK dan tidak punya `BuildContext`.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class RotiGembungApp extends StatelessWidget {
  const RotiGembungApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roti Gembung Panglima',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.light,
      // Pemeriksa update Play membungkus seluruh aplikasi, jadi modalnya
      // muncul di atas layar mana pun — termasuk layar masuk.
      home: const AppUpdateGate(child: _AuthGate()),
    );
  }
}

/// Buka layar yang sesuai setelah notifikasi diketuk.
///
/// Aturannya sama dengan alur pembayaran: **jangan pernah membuka halaman
/// status pesanan tanpa id yang bisa dimuat.** Bila backend tidak mengirim
/// `order_id` numerik, pembeli diantar ke daftar Pesanan — di sana datanya
/// nyata, bukan kerangka kosong.
void handlePushOpen(PushPayload payload) {
  // Ketukan bisa tiba sebelum frame pertama tergambar (aplikasi dingin yang
  // dibuka OLEH notifikasi), jadi tunggu navigator benar-benar ada.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      AppLog.warn('PUSH', 'navigator belum siap — ketukan diabaikan');
      return;
    }
    if (!authStore.isLoggedIn) {
      // Layar login sedang tampil; membuka pesanan orang lain tidak masuk akal.
      AppLog.info('PUSH', 'belum masuk — ketukan diabaikan');
      return;
    }

    if (payload.canOpenOrder) {
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => OrderStatusPage(orderId: payload.orderId),
        ),
      );
      return;
    }

    if (payload.isOrder) {
      AppLog.warn(
        'PUSH',
        'notifikasi pesanan tanpa order_id — buka daftar Pesanan',
        detail: 'Minta backend menyertakan `order_id` numerik pada '
            '`additional_data` agar bisa langsung ke halaman statusnya.',
      );
      navigator.popUntil((route) => route.isFirst);
      selectedPageNotifier.value = ordersTabIndex;
    }
  });
}

/// Gerbang autentikasi: wajib login dulu. Selama belum masuk, tampilkan
/// [LoginLandingPage]; setelah masuk, tampilkan aplikasi ([WidgetTree]).
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserAccount?>(
      valueListenable: authStore.currentUser,
      // Email yang belum diverifikasi TIDAK menutup pintu: pembeli tetap boleh
      // menjelajah menu & harga. Yang ditahan hanya transaksinya — lihat
      // `ensureEmailVerified` di `widgets/verified_email_guard.dart`.
      builder: (context, user, _) =>
          user == null ? const LoginLandingPage() : const WidgetTree(),
    );
  }
}
