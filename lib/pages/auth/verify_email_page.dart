import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  bool get _codeOk => RegExp(r'^\d{6}$').hasMatch(_code.text.trim());

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
            const AuthIllustration(
              url:
                  'https://images.unsplash.com/photo-1526628953301-3e589a6a8b74?w=600&q=60&auto=format&fit=crop',
              height: 160,
              icon: Icons.mark_email_unread_outlined,
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
              _InfoBox(message: _info!),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: true,
              maxLength: 6,
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
                label: 'Kode Verifikasi',
                hint: '000000',
              ).copyWith(counterText: ''),
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

/// Kotak pesan informasi (bukan galat) — mis. konfirmasi kirim ulang kode.
class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.message});

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
