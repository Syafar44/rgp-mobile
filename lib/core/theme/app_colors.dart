import 'package:flutter/material.dart';

/// Semua warna brand Roti Gembung Panglima (lihat `colors.md`).
///
/// Jangan hardcode hex di widget — selalu panggil dari sini.
class AppColors {
  AppColors._(); // supaya tidak bisa di-instantiate

  // ── Brand ──────────────────────────────────────
  static const maroon900 = Color(0xFF4A0A0C);
  static const maroon700 = Color(0xFF7E1416); // PRIMARY
  static const maroon500 = Color(0xFFA32226); // pressed/hover
  static const maroon100 = Color(0xFFF6E3E3);
  static const maroon50 = Color(0xFFFBF1F1);

  static const yellow500 = Color(0xFFF8E600); // SECONDARY
  static const yellow600 = Color(0xFFE5C400);
  static const gold500 = Color(0xFFFFC107); // rating, aksen
  static const yellow100 = Color(0xFFFDF9D6);
  static const yellow50 = Color(0xFFFEFCEA);

  // ── Netral ─────────────────────────────────────
  static const white = Color(0xFFFFFFFF);
  static const creamSurface = Color(0xFFFDFBF2);
  static const grey100 = Color(0xFFF2EFEA);
  static const grey300 = Color(0xFFD9CFC9);
  static const grey400 = Color(0xFF9B948C);
  static const grey600 = Color(0xFF6B6259);
  static const textDark = Color(0xFF2D1B12);

  // ── Status ─────────────────────────────────────
  static const success = Color(0xFF2E7D32);
  static const successBg = Color(0xFFE8F3E9);
  static const error = Color(0xFFC62828);
  static const errorBg = Color(0xFFFBEAEA);
  static const warning = Color(0xFFB26A00);
  static const warningBg = Color(0xFFFFF4E0);
  static const info = Color(0xFF1565C0);
  static const infoBg = Color(0xFFE7F0FA);
}
