import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Foto-foto Panglima yang dipakai alur masuk/daftar & onboarding.
///
/// Satu-satunya tempat path-nya ditulis — ganti di sini bila fotonya diganti.
const String kOutletPhoto = 'assets/img/outlet j2.jpg';
const String kSlide1Photo = 'assets/img/slide1.jpg';
const String kSlide2Photo = 'assets/img/slide2.jpg';
const String kSlide3Photo = 'assets/img/slide3.jpg';

/// Ilustrasi/gambar untuk halaman auth.
///
/// Dua cara pakai:
/// - `AuthIllustration.asset(kOutletPhoto, height: 240)` — gambar dari dalam
///   aplikasi (tidak butuh jaringan, tidak pernah gagal muat).
/// - `AuthIllustration(url: '...')` — gambar dari jaringan.
///
/// **Menyesuaikan ukuran:** ubah [height] (tinggi kotak), [fit] (bagaimana
/// gambar mengisi kotak: `contain` memuat utuh, `cover` memenuhi dengan
/// memotong), dan [borderRadius] (kelengkungan sudut) langsung di tempat
/// pemakaian. Lebarnya mengikuti lebar layar kecuali [width] diisi.
class AuthIllustration extends StatelessWidget {
  /// Gambar dari jaringan.
  const AuthIllustration({
    super.key,
    required String this.url,
    this.height = 200,
    this.width,
    this.icon = Icons.local_cafe,
    this.fit = BoxFit.contain,
    this.borderRadius = 16,
  }) : asset = null;

  /// Gambar dari aset lokal, mis. [kOutletPhoto].
  const AuthIllustration.asset(
    String this.asset, {
    super.key,
    this.height = 200,
    this.width,
    this.icon = Icons.storefront,
    this.fit = BoxFit.contain,
    this.borderRadius = 16,
  }) : url = null;

  final String? url;
  final String? asset;

  /// Tinggi kotak gambar.
  final double height;

  /// Lebar kotak. Null = selebar layar.
  final double? width;

  final IconData icon;

  /// Cara gambar mengisi kotak: `contain` (utuh) atau `cover` (memotong).
  final BoxFit fit;

  /// Kelengkungan sudut. 0 = kotak tajam.
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final local = asset;
    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: local != null
            ? Image.asset(
                local,
                fit: fit,
                errorBuilder: (context, error, stack) => _fallback(),
              )
            : Image.network(
                url!,
                fit: fit,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _fallback(),
                errorBuilder: (context, error, stack) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.maroon50,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 72, color: AppColors.maroon700),
    );
  }
}

/// Dekorasi input konsisten untuk halaman auth.
///
/// [errorText] dipakai untuk galat validasi per field yang datang dari server
/// (lihat `ApiException.validation`).
InputDecoration authInputDecoration({
  required String label,
  String? hint,
  Widget? suffixIcon,
  String? errorText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffixIcon,
    errorText: errorText,
    filled: true,
    fillColor: AppColors.white,
    labelStyle: const TextStyle(color: AppColors.grey600),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.grey300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.maroon700, width: 1.5),
    ),
  );
}

/// Kotak pesan galat untuk halaman auth. Tidak menampilkan apa pun bila
/// [message] null, jadi aman dipasang langsung di dalam daftar widget.
class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotak pesan informasi (bukan galat) — mis. konfirmasi kirim ulang kode.
class AuthInfoBox extends StatelessWidget {
  const AuthInfoBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.maroon50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.maroon700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.maroon700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Input kode 6 digit dari email (verifikasi email & reset kata sandi).
///
/// Hanya menerima angka. Paste langsung berfungsi — termasuk kode yang
/// disalin dengan spasi, karena selain angka dibuang.
class AuthCodeField extends StatelessWidget {
  const AuthCodeField({
    super.key,
    required this.controller,
    required this.label,
    this.autofocus = false,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;

  /// Galat untuk field ini saja, mis. "Kode salah, coba periksa lagi."
  final String? errorText;

  final ValueChanged<String>? onChanged;

  /// True bila [text] tepat 6 digit angka.
  static bool isValid(String text) =>
      RegExp(r'^\d{6}$').hasMatch(text.trim());

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      autofocus: autofocus,
      maxLength: 6,
      onChanged: onChanged,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: 12,
      ),
      decoration: authInputDecoration(
        label: label,
        hint: '000000',
        errorText: errorText,
      ).copyWith(counterText: ''),
    );
  }
}
