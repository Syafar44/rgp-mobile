import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// AppBar reusable untuk halaman-halaman detail (bukan tab utama).
///
/// Tab utama di [WidgetTree] sengaja TIDAK memakai AppBar. Widget ini
/// disediakan agar page lain yang di-`push` (mis. detail produk, keranjang)
/// tinggal memakainya:
///
/// ```dart
/// Scaffold(
///   appBar: AppTopBar(title: 'Detail Produk'),
///   body: ...,
/// );
/// ```
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
    this.onBack,
  });

  final String title;
  final List<Widget>? actions;
  final bool showBack;

  /// Aksi tombol kembali. Null = perilaku bawaan (`Navigator.pop`). Diisi bila
  /// halaman perlu mengembalikan nilai saat ditutup.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      automaticallyImplyLeading: showBack,
      leading: (showBack && onBack != null)
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)
          : null,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
