import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/auth_store.dart';
import 'data/models/user_account.dart';
import 'pages/auth/login_landing_page.dart';
import 'widget_tree.dart';

class RotiGembungApp extends StatelessWidget {
  const RotiGembungApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roti Gembung Panglima',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AuthGate(),
    );
  }
}

/// Gerbang autentikasi: wajib login dulu. Selama belum masuk, tampilkan
/// [LoginLandingPage]; setelah masuk, tampilkan aplikasi ([WidgetTree]).
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserAccount?>(
      valueListenable: authStore.currentUser,
      builder: (context, user, _) =>
          user == null ? const LoginLandingPage() : const WidgetTree(),
    );
  }
}
