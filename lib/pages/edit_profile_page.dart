import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/network/api_error.dart';
import '../core/theme/app_colors.dart';
import '../data/auth_store.dart';
import '../data/customer_repository.dart';
import '../data/models/customer_profile.dart';
import '../widgets/app_top_bar.dart';
import 'auth/auth_widgets.dart';

/// Ubah profil customer (`PATCH /customer/profile`).
///
/// Server mewajibkan ketiga field dikirim sekaligus — termasuk yang tidak
/// berubah — jadi form ini selalu memuat nilai saat ini lebih dulu.
/// Email tidak bisa diubah di sini karena terikat proses verifikasi.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.initial});

  /// Profil yang sudah termuat di halaman sebelumnya. Bila null, diambil
  /// sendiri dari `GET /customer/me`.
  final CustomerProfile? initial;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _address = TextEditingController();

  CustomerProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _fill(initial);
      _loading = false;
    } else {
      _load();
    }
    for (final c in [_name, _contact, _address]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _contact, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(CustomerProfile p) {
    _profile = p;
    _name.text = p.name;
    _contact.text = p.contact;
    _address.text = p.address;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await customerRepository.me();
      if (!mounted) return;
      setState(() {
        if (profile != null) _fill(profile);
        _error = profile == null
            ? 'Profil customer tidak ditemukan untuk akun ini.'
            : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, fallback: 'Gagal memuat profil.');
        _loading = false;
      });
    }
  }

  // --- Aturan validasi (sama dengan form registrasi) -------------------------

  bool get _nameOk {
    final v = _name.text.trim();
    return v.isNotEmpty && v.length <= 255;
  }

  bool get _contactOk {
    final len = _contact.text.trim().length;
    return len >= 8 && len <= 20;
  }

  bool get _addressOk {
    final v = _address.text.trim();
    return v.isNotEmpty && v.length <= 500;
  }

  bool get _canSave =>
      !_saving && !_loading && _nameOk && _contactOk && _addressOk;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      final updated = await customerRepository.updateProfile(
        name: _name.text,
        contact: _contact.text,
        address: _address.text,
      );
      // Balasannya sudah berisi data terbaru — pakai langsung, tanpa GET ulang.
      await authStore.applyCustomer(updated);
      if (!mounted) return;
      Navigator.pop(context, updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil diperbarui.')));
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
      appBar: const AppTopBar(title: 'Ubah Profil'),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.maroon700),
            )
          : AbsorbPointer(
              absorbing: _saving,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  AuthErrorBox(message: _error),
                  if (_profile != null) ...[
                    _ReadOnlyField(
                      label: 'Email',
                      value: _profile!.email,
                      note: 'Tidak bisa diubah karena terikat verifikasi.',
                    ),
                    const SizedBox(height: 14),
                    if (_profile!.code.isNotEmpty) ...[
                      _ReadOnlyField(
                        label: 'Kode Customer',
                        value: _profile!.code,
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [LengthLimitingTextInputFormatter(255)],
                    decoration: authInputDecoration(
                      label: 'Nama Lengkap *',
                      hint: 'Masukkan nama lengkap',
                      errorText: _fieldErrors['name'],
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
                  const SizedBox(height: 24),
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
                              'Simpan Perubahan',
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

/// Field yang hanya ditampilkan, tidak bisa diubah.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.creamSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.grey600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppColors.textDark),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: const TextStyle(fontSize: 11, color: AppColors.grey400),
            ),
          ],
        ],
      ),
    );
  }
}
