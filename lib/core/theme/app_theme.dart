import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Tema aplikasi Roti Gembung Panglima — mengikuti panduan `colors.md`:
/// latar putih dominan, maroon sebagai warna aksi/brand, kuning/emas aksen.
class AppTheme {
  /// Warna brand utama (maroon).
  static const Color brand = AppColors.maroon700;

  static const ColorScheme _scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.maroon700,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.maroon100,
    onPrimaryContainer: AppColors.maroon900,
    secondary: AppColors.yellow500,
    onSecondary: AppColors.maroon900, // teks di atas kuning = gelap!
    secondaryContainer: AppColors.yellow100,
    onSecondaryContainer: AppColors.maroon900,
    tertiary: AppColors.gold500,
    onTertiary: AppColors.maroon900,
    surface: AppColors.white,
    onSurface: AppColors.textDark,
    onSurfaceVariant: AppColors.grey600,
    outline: AppColors.grey300,
    outlineVariant: AppColors.grey100,
    error: AppColors.error,
    onError: AppColors.white,
  );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: _scheme,
        scaffoldBackgroundColor: AppColors.white,
        cardColor: AppColors.creamSurface,
        dividerColor: AppColors.grey100,
        dividerTheme: const DividerThemeData(
          color: AppColors.grey100,
          thickness: 1,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.maroon700,
          foregroundColor: AppColors.white,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          // AppBar maroon (gelap) → ikon status bar putih.
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.white,
          indicatorColor: AppColors.maroon100,
          elevation: 3,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? AppColors.maroon700 : AppColors.grey400,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? AppColors.maroon700 : AppColors.grey400,
            );
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.maroon700,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.grey300,
            disabledForegroundColor: AppColors.grey400,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.maroon700,
            foregroundColor: AppColors.white,
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.maroon700,
            side: const BorderSide(color: AppColors.maroon700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.maroon700),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.textDark,
          contentTextStyle: TextStyle(color: AppColors.white),
          behavior: SnackBarBehavior.floating,
        ),
      );
}
