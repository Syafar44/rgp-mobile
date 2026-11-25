import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../data/auth_store.dart';
import '../../widgets/app_top_bar.dart';
import 'auth_widgets.dart';

/// Halaman verifikasi email: masukkan kode OTP 6 digit yang dikirim ke email.
///
/// Setelah `POST /verify_email` sukses, aplikasi WAJIB memanggil `POST /auth`
/// lagi karena `email_verified` dibekukan di dalam token saat login. Keduanya
/// dijalankan sekaligus oleh `AuthRepository.verifyEmailAndRefresh`.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({
    super.key,
    required this.email,
    required this.password,
    required this.phone,
  });

  final String email;

  /// Dipakai untuk login ulang otomatis setelah verifikasi berhasil.
  final String password;

  /// Nomor HP (contact) — identitas akun di sisi aplikasi.
  final String phone;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  static const int _resendCooldown = 60;

  final _code = TextEditingController();

  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _info;

  /// Sisa detik sebelum tombol "Kirim ulang" bisa ditekan lagi.
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  bool get _codeOk => AuthCodeField.isValid(_code.text);

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  // --- Aksi ------------------------------------------------------------------

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _verifying = true;
      _error = null;
      _info = null;
    });
    try {
      // Verifikasi + login ulang (token baru membawa email_verified: true).
      final session = await authRepository.verifyEmailAndRefresh(
        email: widget.email,
        code: _code.text.trim(),
        password: widget.password,
      );
      await authStore.applySession(session, phone: widget.phone);
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((r) => r.isFirst);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Email terverifikasi. Selamat datang, ${session.name}!'),
          duration: const Duration(seconds: 3),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      await authRepository.resendVerify(widget.email);
      if (!mounted) return;
      // Balasan server selalu sama, terdaftar maupun tidak — pesannya sengaja
      // dibuat netral, jangan menyiratkan email itu pasti ada.
      setState(
        () => _info =
            'Bila email terdaftar, kode verifikasi baru sudah dikirim. '
            'Cek juga folder spam.',
      );
      _startCooldown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  /// Lewati dulu — pengguna sudah punya token (email_verified: false) dan
  /// boleh melihat katalog. Verifikasi bisa dilanjutkan nanti dari Profile.
  void _skip() => Navigator.of(context).popUntil((r) => r.isFirst);

  // --- Tampilan --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final busy = _verifying || _resending;
    return Scaffold(
      appBar: const AppTopBar(title: 'Verifikasi Email'),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Foto outlet dari dalam aplikasi, sama dengan halaman masuk &
            // daftar. Sebelumnya foto acak dari Unsplash: butuh jaringan,
            // dan tidak ada hubungannya dengan Panglima.
            const AuthIllustration.asset(
              kOutletPhoto,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            const Text(
              'Cek Email Kamu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'Kami mengirim kode 6 digit ke ',
                style: TextStyle(fontSize: 14, color: AppColors.grey600),
                children: [
                  TextSpan(
                    text: widget.email,
                    style: const TextStyle(
                      color: AppColors.maroon700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: '. Kode berlaku 15 menit.'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AuthErrorBox(message: _error),
            if (_info != null) ...[
              AuthInfoBox(message: _info!),
              const SizedBox(height: 14),
            ],
            AuthCodeField(
              controller: _code,
              label: 'Kode Verifikasi',
              autofocus: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: (_codeOk && !busy) ? _verify : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon700,
                  disabledBackgroundColor: AppColors.grey300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _verifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text(
                        'Verifikasi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: (_cooldown > 0 || busy) ? null : _resend,
                child: Text(
                  _cooldown > 0
                      ? 'Kirim ulang kode dalam ${_cooldown}s'
                      : 'Tidak menerima kode? Kirim ulang',
                  style: TextStyle(
                    color: _cooldown > 0
                        ? AppColors.grey400
                        : AppColors.maroon700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: busy ? null : _skip,
                child: Text(
                  'Nanti saja',
                  style: TextStyle(color: AppColors.grey600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
