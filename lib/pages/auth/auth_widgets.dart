import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Ilustrasi/gambar dummy untuk halaman auth. Memuat dari jaringan; bila null
/// atau gagal, menampilkan placeholder ikon (tanpa gambar rusak).
class AuthIllustration extends StatelessWidget {
  const AuthIllustration({
    super.key,
    required this.url,
    this.height = 200,
    this.icon = Icons.local_cafe,
    this.fit = BoxFit.contain,
  });

  final String url;
  final double height;
  final IconData icon;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.network(
        url,
        fit: fit,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _fallback(),
        errorBuilder: (context, error, stack) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.maroon50,
        borderRadius: BorderRadius.circular(16),
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
