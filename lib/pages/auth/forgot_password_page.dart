import 'package:flutter/material.dart';

import '../../core/network/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/network_guard.dart';
import 'auth_widgets.dart';
import 'reset_password_page.dart';

/// Lupa kata sandi, layar 1: minta kode reset ke email
/// (`POST /customer/forgot-password`).
///
/// Server membalas `200` yang sama persis untuk email terdaftar maupun tidak
/// — disengaja, supaya endpoint ini tidak bisa dipakai menebak email mana
/// yang punya akun. Jadi setelah `200`, layar kode **selalu** dibuka dan
/// aplikasi tidak pernah berkata "email tidak ditemukan".
///
/// Ditutup dengan email (String) bila kata sandi sudah terganti tetapi masuk
/// otomatis gagal — halaman Masuk lalu mengisinya untuk pengguna.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  /// Diambil dari field email di halaman Masuk, bila sudah diisi.
  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail.trim(),
  );

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  /// Sama seperti server menyimpannya: tanpa spasi, huruf kecil.
  String get _normalized => _email.text.trim().toLowerCase();

  bool get _emailValid =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_normalized) &&
      _normalized.length <= 255;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!await ensureNetworkReady(context) || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = _normalized;
    try {
      await authRepository.forgotPassword(email);
      if (!mounted) return;
      setState(() => _loading = false);
      final perluMasuk = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => ResetPasswordPage(email: email)),
      );
      // Kata sandi sudah terganti, masuk otomatis gagal → teruskan ke Masuk.
      if (perluMasuk != null && mounted) Navigator.pop(context, perluMasuk);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Lupa Kata Sandi'),
      body: AbsorbPointer(
        absorbing: _loading,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const AuthIllustration.asset(
              kOutletPhoto,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            const Text(
              'Lupa Kata Sandi?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Masukkan email akun Panglima-mu. Kami kirim kode 6 digit untuk '
              'mengatur ulang kata sandi.',
              style: TextStyle(fontSize: 14, color: AppColors.grey600),
            ),
            const SizedBox(height: 20),
            AuthErrorBox(message: _error),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofocus: widget.initialEmail.trim().isEmpty,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) {
                if (_emailValid && !_loading) _submit();
              },
              decoration: authInputDecoration(
                label: 'Email',
                hint: 'cth: nama@email.com',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: (_emailValid && !_loading) ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon700,
                  disabledBackgroundColor: AppColors.grey300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text(
                        'Kirim Kode',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
