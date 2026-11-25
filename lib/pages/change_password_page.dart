import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/network/api_error.dart';
import '../core/theme/app_colors.dart';
import '../data/customer_repository.dart';
import '../widgets/app_top_bar.dart';
import 'auth/auth_widgets.dart';

/// Ubah kata sandi (`PATCH /customer/password`).
///
/// Sesi yang sedang berjalan **tetap berlaku** setelah berhasil — server tidak
/// mencabut token. Jadi pengguna tidak perlu masuk ulang.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    for (final c in [_old, _new, _confirm]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_old, _new, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  // --- Aturan server: 8–72 karakter (batas 72 mengikuti bcrypt) -------------

  bool get _minLen => _new.text.length >= 8;
  bool get _maxLen => _new.text.length <= 72;
  bool get _match => _new.text.isNotEmpty && _new.text == _confirm.text;
  bool get _oldFilled => _old.text.isNotEmpty;

  bool get _canSave =>
      !_saving && _oldFilled && _minLen && _maxLen && _match;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await customerRepository.changePassword(
        oldPassword: _old.text,
        newPassword: _new.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kata sandi berhasil diubah.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
        _fieldErrors = e.validation;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Ubah Kata Sandi'),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            AuthErrorBox(message: _error),
            TextField(
              controller: _old,
              obscureText: _obscureOld,
              decoration: authInputDecoration(
                label: 'Kata Sandi Lama *',
                hint: 'Masukkan kata sandi saat ini',
                errorText: _fieldErrors['old_password'],
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureOld ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.grey400,
                  ),
                  onPressed: () => setState(() => _obscureOld = !_obscureOld),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _new,
              obscureText: _obscureNew,
              inputFormatters: [LengthLimitingTextInputFormatter(72)],
              decoration: authInputDecoration(
                label: 'Kata Sandi Baru *',
                hint: 'Minimal 8 karakter',
                errorText: _fieldErrors['new_password'],
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.grey400,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirm,
              obscureText: _obscureConfirm,
              inputFormatters: [LengthLimitingTextInputFormatter(72)],
              decoration: authInputDecoration(
                label: 'Konfirmasi Kata Sandi Baru *',
                hint: 'Ulangi kata sandi baru',
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
              'Kata sandi baru wajib',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _Rule(ok: _minLen && _maxLen, text: 'Antara 8 dan 72 karakter'),
            _Rule(ok: _match, text: 'Sama dengan kolom konfirmasi'),
            const SizedBox(height: 12),
            Text(
              'Anda tetap masuk setelah kata sandi diubah — tidak perlu login '
              'ulang.',
              style: TextStyle(fontSize: 12, color: AppColors.grey600),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
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
                        'Simpan Kata Sandi',
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
