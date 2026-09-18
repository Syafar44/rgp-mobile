import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../data/auth_store.dart';
import '../../widgets/app_top_bar.dart';
import 'auth_widgets.dart';
import 'verify_email_page.dart';

/// Halaman registrasi ("Atur Kata Sandi").
///
/// Memanggil `POST /register` lalu `POST /auth` (langkah 1-2 pada
/// API_REGISTER_FLUTTER.md), menyimpan sesi, dan melanjutkan ke halaman
/// verifikasi kode OTP.
///
/// Nilai dari halaman sebelumnya dibawa lewat [phone]: bisa nomor HP atau
/// email, jadi diisikan ke field yang sesuai.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.phone});

  final String phone;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _agree = false;
  bool _loading = false;

  /// Pesan galat umum dari server (mis. email sudah terdaftar).
  String? _error;

  /// Galat per field dari `validation` server: nama field → pesan.
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    // Halaman sebelumnya menerima "Nomor Handphone/Email" — tebak isinya.
    if (widget.phone.contains('@')) {
      _email.text = widget.phone.trim();
    } else {
      _contact.text = widget.phone.trim();
    }
    for (final c in [
      _name,
      _email,
      _contact,
      _address,
      _password,
      _confirm,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _contact,
      _address,
      _password,
      _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // --- Aturan validasi (mengikuti aturan field `/register`) -------------------

  /// Server: minimal 8 karakter.
  bool get _minLen => _password.text.length >= 8;

  /// Server: maksimal 72 karakter (batas bcrypt).
  bool get _maxLen => _password.text.length <= 72;

  bool get _hasMix =>
      RegExp(r'[0-9]').hasMatch(_password.text) &&
      RegExp(r'[A-Za-z]').hasMatch(_password.text);
  bool get _match =>
      _password.text.isNotEmpty && _password.text == _confirm.text;
  bool get _nameOk => _name.text.trim().isNotEmpty;
  bool get _emailOk =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  /// Server: 8–20 karakter.
  bool get _contactOk {
    final len = _contact.text.trim().length;
    return len >= 8 && len <= 20;
  }

  /// Server: wajib, maksimal 500 karakter.
  bool get _addressOk {
    final text = _address.text.trim();
    return text.isNotEmpty && text.length <= 500;
  }

  bool get _canSubmit =>
      !_loading &&
      _nameOk &&
      _emailOk &&
      _contactOk &&
      _addressOk &&
      _minLen &&
      _maxLen &&
      _hasMix &&
      _match &&
      _agree;

  // --- Aksi ------------------------------------------------------------------

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _fieldErrors = const {};
    });

    final email = _email.text.trim().toLowerCase();
    final contact = _contact.text.trim();
    final address = _address.text.trim();
    final password = _password.text;

    try {
      // Daftar → langsung login supaya dapat token (respons /register tidak
      // membawa token). Token disimpan oleh `applySession`.
      final session = await authRepository.registerAndLogin(
        name: _name.text.trim(),
        email: email,
        password: password,
        contact: contact,
        address: address,
      );
      await authStore.applySession(session, phone: contact, address: address);
      if (!mounted) return;

      // Lanjut ke verifikasi kode OTP (langkah 3-5).
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VerifyEmailPage(
            email: email,
            password: password,
            phone: contact,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _fieldErrors = e.validation;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            const Text(
              'Atur Kata Sandi',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Lengkapi data di bawah untuk membuat akun Panglima.',
              style: TextStyle(fontSize: 13, color: AppColors.grey600),
            ),
            const SizedBox(height: 20),
            AuthErrorBox(message: _error),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: authInputDecoration(
                label: 'Nama Lengkap *',
                hint: 'Masukkan nama lengkap',
                errorText: _fieldErrors['name'],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: authInputDecoration(
                label: 'Email *',
                hint: 'Masukkan alamat email',
                errorText: _fieldErrors['email'],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _contact,
              keyboardType: TextInputType.phone,
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
              decoration: authInputDecoration(
                label: 'Nomor Handphone *',
                hint: 'cth: 081234567890',
                errorText: _fieldErrors['contact'],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _address,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
              decoration: authInputDecoration(
                label: 'Alamat *',
                hint: 'cth: Jl. Merdeka No. 10, Samarinda',
                errorText: _fieldErrors['address'],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: _obscurePass,
              inputFormatters: [LengthLimitingTextInputFormatter(72)],
              decoration: authInputDecoration(
                label: 'Kata Sandi *',
                hint: 'Masukkan kata sandi',
                errorText: _fieldErrors['password'],
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.grey400,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirm,
              obscureText: _obscureConfirm,
              inputFormatters: [LengthLimitingTextInputFormatter(72)],
              decoration: authInputDecoration(
                label: 'Konfirmasi Kata Sandi *',
                hint: 'Ulangi kata sandi',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.grey400,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Kata sandi wajib mengandung',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _Rule(ok: _minLen, text: 'Minimum 8 karakter'),
            _Rule(ok: _hasMix, text: 'Terdapat campuran angka dan huruf'),
            _Rule(
              ok: _match,
              text: 'Kata sandi baru dan konfirmasi harus sama',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  value: _agree,
                  onChanged: (v) => setState(() => _agree = v ?? false),
                  activeColor: AppColors.maroon700,
                ),
                const Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Dengan mendaftar, saya menyetujui ',
                      children: [
                        TextSpan(
                          text: 'syarat & ketentuan',
                          style: TextStyle(
                            color: AppColors.maroon700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(text: ' dari Roti Gembung Panglima'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                        'Simpan dan Daftar',
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

class _Rule extends StatelessWidget {
  const _Rule({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.grey400;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.check_circle_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: color)),
          ),
        ],
      ),
    );
  }
}
