import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../data/auth_store.dart';
import '../../data/notifiers.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/network_guard.dart';
import 'auth_widgets.dart';

/// Lupa kata sandi, layar 2: kode dari email + kata sandi baru
/// (`POST /customer/reset-password`), lalu langsung masuk (`POST /auth`).
///
/// Email datang dari layar 1 dan dikirim apa adanya — server mewajibkannya
/// sama dengan yang meminta kode. Konfirmasi kata sandi hanya dicocokkan di
/// sini; server menerima satu field `password`.
///
/// Ditutup dengan email (String) bila kata sandi sudah terganti tetapi masuk
/// otomatis gagal. Ditutup tanpa hasil lewat "Ganti email".
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.email});

  /// Sudah dinormalisasi layar 1 (trim + huruf kecil).
  final String email;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  /// Jeda kirim ulang — menjaga jatah 3 kode per jam per email.
  static const int _resendCooldown = 60;
  static const int _minPassword = 8;

  /// Batas bcrypt di server.
  static const int _maxPassword = 72;

  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _saving = false;
  bool _resending = false;

  String? _error;
  String? _info;

  /// Galat per field dari server.
  String? _codeError;
  String? _passwordError;

  /// Kode yang dipegang pengguna sudah mati — tombol kirim ulang disorot.
  bool _perluKodeBaru = false;

  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    for (final c in [_code, _password, _confirm]) {
      c.addListener(() => setState(() {}));
    }
    // Kode pertama baru saja diminta di layar 1 — hitung mundur dari sana.
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _busy => _saving || _resending;

  bool get _codeOk => AuthCodeField.isValid(_code.text);

  /// Galat lokal kata sandi baru, atau null bila valid / masih kosong.
  String? get _passwordLocalError {
    final n = _password.text.length;
    if (n == 0) return null;
    if (n < _minPassword) return 'Kata sandi minimal $_minPassword karakter.';
    if (n > _maxPassword) return 'Kata sandi maksimal $_maxPassword karakter.';
    return null;
  }

  String? get _confirmError =>
      _confirm.text.isNotEmpty && _confirm.text != _password.text
      ? 'Konfirmasi kata sandi tidak sama.'
      : null;

  bool get _canSubmit =>
      !_busy &&
      _codeOk &&
      _password.text.isNotEmpty &&
      _passwordLocalError == null &&
      _confirm.text == _password.text;

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

  void _clearMessages() {
    _error = null;
    _info = null;
    _codeError = null;
    _passwordError = null;
  }

  // --- Aksi ------------------------------------------------------------------

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!await ensureNetworkReady(context) || !mounted) return;
    setState(() {
      _saving = true;
      _clearMessages();
    });
    try {
      final session = await authRepository.resetPasswordAndLogin(
        email: widget.email,
        code: _code.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      if (session == null) {
        // Kata sandi sudah terganti; hanya masuk otomatisnya yang gagal.
        Navigator.pop(context, widget.email);
        return;
      }
      // Token lama ditimpa. Token baru membawa `email_verified: true`, jadi
      // penjaga "email belum terverifikasi" ikut terbuka.
      await authStore.applySession(session);
      if (!mounted) return;
      selectedPageNotifier.value = 0; // Beranda
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((r) => r.isFirst);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Kata sandi berhasil diganti'),
          duration: Duration(seconds: 3),
        ),
      );
    } on ResetPasswordException catch (e) {
      if (!mounted) return;
      setState(() {
        _codeError = e.validation['code'];
        _passwordError = e.validation['password'];
        final lainnya = e.validation.keys.where(
          (k) => k != 'code' && k != 'password',
        );
        // Pesan umum hanya bila galatnya tidak bisa ditempel ke satu field.
        if (!e.hasValidation || lainnya.isNotEmpty) _error = e.message;
        if (e.kosongkanKode) _code.clear();
        if (e.mintaKodeBaru) _perluKodeBaru = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resend() async {
    if (!await ensureNetworkReady(context) || !mounted) return;
    setState(() {
      _resending = true;
      _clearMessages();
    });
    try {
      await authRepository.forgotPassword(widget.email);
      if (!mounted) return;
      setState(() {
        // Kode baru langsung membatalkan kode sebelumnya.
        _code.clear();
        _perluKodeBaru = false;
        _info =
            'Bila email terdaftar, kode baru sudah dikirim. Kode sebelumnya '
            'otomatis tidak berlaku.';
      });
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

  // --- Tampilan --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Atur Ulang Kata Sandi'),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Cek Email Kamu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Netral: server tidak memberi tahu apakah email ini terdaftar.
            Text.rich(
              TextSpan(
                text: 'Bila email terdaftar, kode reset sudah kami kirim ke ',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.grey600,
                ),
                children: [
                  TextSpan(
                    text: widget.email,
                    style: const TextStyle(
                      color: AppColors.maroon700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(
                    text:
                        '. Cari email berjudul "Kode reset password Panglima '
                        'Apps", periksa juga folder spam. Kode berlaku 15 '
                        'menit.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _EmailTerkunci(
              email: widget.email,
              onGanti: _busy ? null : () => Navigator.pop(context),
            ),
            const SizedBox(height: 20),
            AuthErrorBox(message: _error),
            if (_info != null) ...[
              AuthInfoBox(message: _info!),
              const SizedBox(height: 14),
            ],
            AuthCodeField(
              controller: _code,
              label: 'Kode Reset',
              autofocus: true,
              errorText: _codeError,
              onChanged: (_) {
                if (_codeError != null) setState(() => _codeError = null);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: _obscure,
              onChanged: (_) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
              decoration: authInputDecoration(
                label: 'Kata Sandi Baru',
                hint: '$_minPassword–$_maxPassword karakter',
                errorText: _passwordLocalError ?? _passwordError,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.grey400,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirm,
              obscureText: _obscure,
              onSubmitted: (_) {
                if (_canSubmit) _submit();
              },
              decoration: authInputDecoration(
                label: 'Ulangi Kata Sandi Baru',
                hint: 'Ketik ulang kata sandi baru',
                errorText: _confirmError,
              ),
            ),
            const SizedBox(height: 20),
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
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text(
                        'Simpan Kata Sandi Baru',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            _KirimUlang(
              cooldown: _cooldown,
              sorot: _perluKodeBaru,
              loading: _resending,
              onTap: (_cooldown > 0 || _busy) ? null : _resend,
            ),
          ],
        ),
      ),
    );
  }
}

/// Email tujuan kode (read-only) beserta tautan kembali ke layar 1.
class _EmailTerkunci extends StatelessWidget {
  const _EmailTerkunci({required this.email, required this.onGanti});

  final String email;
  final VoidCallback? onGanti;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.creamSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Row(
        children: [
          const Icon(Icons.mail_outline, size: 18, color: AppColors.grey400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
          TextButton(
            onPressed: onGanti,
            child: const Text(
              'Ganti email',
              style: TextStyle(
                color: AppColors.maroon700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol kirim ulang kode.
///
/// Biasanya tautan teks. Saat kode yang dipegang pengguna sudah mati
/// ([sorot]) — kedaluwarsa atau 5× salah — berubah menjadi tombol penuh,
/// karena satu-satunya jalan lanjut adalah meminta kode baru.
class _KirimUlang extends StatelessWidget {
  const _KirimUlang({
    required this.cooldown,
    required this.sorot,
    required this.loading,
    required this.onTap,
  });

  final int cooldown;
  final bool sorot;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = cooldown > 0
        ? 'Kirim ulang kode dalam ${cooldown}s'
        : sorot
        ? 'Minta Kode Baru'
        : 'Tidak menerima kode? Kirim ulang';

    if (sorot) {
      return SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.maroon700,
                  ),
                )
              : const Icon(Icons.refresh, size: 18),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.maroon700,
            backgroundColor: AppColors.maroon50,
            side: const BorderSide(color: AppColors.maroon700, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            color: cooldown > 0 ? AppColors.grey400 : AppColors.maroon700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
