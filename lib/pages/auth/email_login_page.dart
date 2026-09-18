import 'package:flutter/material.dart';

import '../../core/network/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../data/auth_store.dart';
import '../../widgets/app_top_bar.dart';
import 'auth_widgets.dart';
import 'register_page.dart';
import 'verify_email_page.dart';

/// Halaman masuk: **email + kata sandi dalam satu halaman** (`POST /auth`).
///
/// Identitas login di server adalah email. Tidak ada pengecekan lokal —
/// server yang memverifikasi kredensial. Pengguna baru lewat "Daftar".
class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _emailValid =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  bool get _canSubmit =>
      !_loading && _emailValid && _password.text.isNotEmpty;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await authRepository.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      await authStore.applySession(session);
      if (!mounted) return;

      // Belum terverifikasi → arahkan ke layar kode OTP (kata sandi masih di
      // tangan, jadi login ulang setelah verifikasi bisa otomatis).
      if (!session.emailVerified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VerifyEmailPage(
              email: session.email,
              password: _password.text,
              phone: '',
            ),
          ),
        );
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((r) => r.isFirst);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Selamat datang kembali, ${session.name}!'),
          duration: const Duration(seconds: 2),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _register() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RegisterPage(phone: _email.text.trim())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Masuk atau Daftar Akun'),
      body: AbsorbPointer(
        absorbing: _loading,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const AuthIllustration(
              url:
                  'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=600&q=60&auto=format&fit=crop',
              height: 180,
              icon: Icons.storefront,
            ),
            const SizedBox(height: 20),
            const Text(
              'Halo!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Masuk dengan email & kata sandi akun Panglima-mu.',
              style: TextStyle(fontSize: 14, color: AppColors.grey600),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: authInputDecoration(
                label: 'Email',
                hint: 'cth: nama@email.com',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: _obscure,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) {
                if (_canSubmit) _submit();
              },
              decoration: authInputDecoration(
                label: 'Kata Sandi',
                hint: 'Masukkan kata sandi',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.grey400,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pemulihan kata sandi belum tersedia'),
                    duration: Duration(seconds: 1),
                  ),
                ),
                child: const Text('Lupa kata sandi?'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _canSubmit ? _submit : null,
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
                        'Masuk',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _loading ? null : _register,
                child: const Text(
                  'Belum punya akun? Daftar',
                  style: TextStyle(
                    color: AppColors.maroon700,
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

/// Bottom sheet sambutan ("Login untuk Berbelanja") → tombol Gabung Sekarang.
void showLoginWelcome(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => _WelcomeSheet(
      onJoin: () {
        Navigator.pop(sheetCtx);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmailLoginPage()),
        );
      },
    ),
  );
}

class _WelcomeSheet extends StatelessWidget {
  const _WelcomeSheet({required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Login untuk Berbelanja',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const AuthIllustration(
              url:
                  'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&q=60&auto=format&fit=crop',
              height: 180,
              icon: Icons.bakery_dining,
            ),
            const SizedBox(height: 16),
            const Text(
              'Selamat datang di Roti Gembung Panglima!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Jalani harimu dengan roti gembung & kopi Panglima yang fresh '
              'dan berkualitas melalui satu aplikasi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.grey600),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: onJoin,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Gabung Sekarang',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
