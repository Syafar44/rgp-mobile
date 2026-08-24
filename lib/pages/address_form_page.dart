import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/address_store.dart';
import '../data/models/saved_address.dart';
import 'map_picker_page.dart';

/// Form tambah / edit alamat delivery ("Detail Alamat").
///
/// [existing] null → mode tambah (prefill dari lokasi saat ini, dummy).
/// [existing] terisi → mode edit (bisa hapus alamat).
class AddressFormPage extends StatefulWidget {
  const AddressFormPage({
    super.key,
    this.existing,
    this.initialAddress,
    this.initialLabel,
    this.initialLat,
    this.initialLon,
  });

  final SavedAddress? existing;

  /// Alamat awal (mis. hasil pilih di peta) untuk mode tambah.
  final String? initialAddress;

  /// Saran "Nama Alamat" dari peta (nama jalan/tempat).
  final String? initialLabel;

  /// Koordinat awal dari peta.
  final double? initialLat;
  final double? initialLon;

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  // Alamat hasil geolokasi (dummy untuk mode tambah).
  static const String _detectedAddress =
      'Jl. Ir. H. Juanda No.88, Sidodadi, Kec. Samarinda Ulu, '
      'Kota Samarinda, Kalimantan Timur 75124';

  late String _fullAddress;
  double? _lat;
  double? _lon;
  late final TextEditingController _note;
  late final TextEditingController _label;
  late final TextEditingController _recipient;
  late final TextEditingController _phone;
  late bool _isPrimary;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _fullAddress = e?.fullAddress ?? widget.initialAddress ?? _detectedAddress;
    _lat = e?.lat ?? widget.initialLat;
    _lon = e?.lon ?? widget.initialLon;
    _note = TextEditingController(text: e?.note ?? '');
    _label = TextEditingController(text: e?.label ?? widget.initialLabel ?? '');
    _recipient = TextEditingController(text: e?.recipient ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _isPrimary = e?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _note.dispose();
    _label.dispose();
    _recipient.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _valid =>
      _label.text.trim().isNotEmpty &&
      _recipient.text.trim().isNotEmpty &&
      _phone.text.trim().isNotEmpty;

  void _submit() {
    final address = SavedAddress(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      label: _label.text.trim(),
      fullAddress: _fullAddress,
      recipient: _recipient.text.trim(),
      phone: _phone.text.trim(),
      note: _note.text.trim(),
      isPrimary: _isPrimary,
      lat: _lat,
      lon: _lon,
    );
    if (_isEdit) {
      addressStore.update(address);
    } else {
      addressStore.add(address);
    }
    Navigator.pop(context);
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerPage()),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _fullAddress = picked.fullAddress;
      _lat = picked.lat;
      _lon = picked.lon;
      // Isi otomatis Nama Alamat bila masih kosong.
      if (_label.text.trim().isEmpty) _label.text = picked.title;
    });
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Alamat'),
        content: const Text('Yakin ingin menghapus alamat ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      addressStore.remove(widget.existing!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detail Alamat',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _pickOnMap,
            icon: const Icon(Icons.map_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            _fullAddress.split(',').first,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _fullAddress,
            style: const TextStyle(fontSize: 13, color: AppColors.grey600),
          ),
          const Divider(height: 28),
          _LabeledField(
            label: 'Catatan Spesial',
            controller: _note,
            hint: 'Contoh nomor rumah ATAU patokan lainnya',
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          _LabeledField(
            label: 'Nama Alamat',
            controller: _label,
            hint: 'Contoh Rumahku / Kantorku',
            required: true,
            onChanged: (_) => setState(() {}),
          ),
          _LabeledField(
            label: 'Penerima',
            controller: _recipient,
            hint: 'Nama penerima',
            required: true,
            onChanged: (_) => setState(() {}),
          ),
          _LabeledField(
            label: 'No. Telepon',
            controller: _phone,
            hint: '08xxxxxxxxxx',
            required: true,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          _PrimarySwitch(
            value: _isPrimary,
            onChanged: (v) => setState(() => _isPrimary = v),
          ),
          if (_isEdit) ...[
            const Divider(height: 28),
            TextButton.icon(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              label: const Text(
                'Hapus Alamat',
                style: TextStyle(color: AppColors.error),
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _valid ? _submit : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Lanjutkan'),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// FIELD BERLABEL
// =============================================================================

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              if (required)
                const Text(' *', style: TextStyle(color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.grey400),
              filled: true,
              fillColor: AppColors.grey100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.maroon700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ALAMAT UTAMA (toggle)
// =============================================================================

class _PrimarySwitch extends StatelessWidget {
  const _PrimarySwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _RoundStar(),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alamat Utama',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Jadikan alamat utama untuk delivery',
                style: TextStyle(fontSize: 12, color: AppColors.grey600),
              ),
            ],
          ),
        ),
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: AppColors.maroon700,
        ),
      ],
    );
  }
}

class _RoundStar extends StatelessWidget {
  const _RoundStar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.yellow50,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.star, color: AppColors.gold500, size: 20),
    );
  }
}
