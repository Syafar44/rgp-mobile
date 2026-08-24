import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/address_store.dart';
import '../data/geocoding_service.dart';
import '../data/location_service.dart';
import '../data/models/saved_address.dart';
import '../widgets/app_top_bar.dart';
import 'address_form_page.dart';
import 'map_picker_page.dart';

/// Halaman **Alamat Pengiriman** — daftar alamat tersimpan sekaligus fungsi
/// menambah alamat (manual, dari GPS, atau dari peta).
///
/// Sebelumnya berupa tab Delivery pada MethodPage; kini berdiri sendiri dan
/// dipakai dari tombol "Ubah" alamat (Konfirmasi Pesanan) & menu Profile.
class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  String _query = '';
  bool _locating = false;

  /// Ambil GPS perangkat, terjemahkan jadi alamat, lalu buka form terisi.
  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final pos = await locationService.getCurrentPosition();
      final geo = await geocodingService.reverse(pos.latitude, pos.longitude);
      if (!mounted) return;
      await _openForm(
        initialAddress:
            geo?.displayName ??
            'Lokasi (${pos.latitude.toStringAsFixed(5)}, '
                '${pos.longitude.toStringAsFixed(5)})',
        initialLabel: geo?.shortName,
        initialLat: pos.latitude,
        initialLon: pos.longitude,
      );
    } on LocationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openForm({
    SavedAddress? existing,
    String? initialAddress,
    String? initialLabel,
    double? initialLat,
    double? initialLon,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressFormPage(
          existing: existing,
          initialAddress: initialAddress,
          initialLabel: initialLabel,
          initialLat: initialLat,
          initialLon: initialLon,
        ),
      ),
    );
  }

  Future<void> _openMap() async {
    final picked = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerPage()),
    );
    if (picked == null || !mounted) return;
    await _openForm(
      initialAddress: picked.fullAddress,
      initialLabel: picked.title,
      initialLat: picked.lat,
      initialLon: picked.lon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Alamat Pengiriman'),
      body: Column(
        children: [
          _SearchField(
            hint: 'Cari alamat',
            onChanged: (v) => setState(() => _query = v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _locating ? null : _useCurrentLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 20),
                    label: Text(
                      _locating
                          ? 'Mengambil lokasi...'
                          : 'Gunakan lokasi saat ini',
                    ),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      side: const BorderSide(color: AppColors.maroon700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _openMap,
                  icon: const Icon(Icons.map_outlined),
                  color: AppColors.maroon700,
                ),
              ],
            ),
          ),
          // Tambah alamat manual (form kosong).
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const _RoundIcon(
              icon: Icons.add_location_alt_outlined,
              background: AppColors.maroon50,
              foreground: AppColors.maroon700,
            ),
            title: const Text(
              'Tambah Alamat Baru',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.grey400),
            onTap: () => _openForm(),
          ),
          const Divider(height: 1),
          Expanded(
            child: ValueListenableBuilder<List<SavedAddress>>(
              valueListenable: addressStore.notifier,
              builder: (context, addresses, _) {
                final q = _query.toLowerCase();
                final list = addresses
                    .where(
                      (a) =>
                          a.label.toLowerCase().contains(q) ||
                          a.fullAddress.toLowerCase().contains(q),
                    )
                    .toList();
                if (list.isEmpty) {
                  return const _EmptyText('Belum ada alamat tersimpan');
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 68, endIndent: 16),
                  itemBuilder: (context, i) =>
                      _AddressTile(address: list[i], onEdit: _openForm),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({required this.address, required this.onEdit});

  final SavedAddress address;
  final Future<void> Function({SavedAddress existing}) onEdit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: _RoundIcon(
        icon: address.isPrimary ? Icons.star : Icons.bookmark,
        background: address.isPrimary ? AppColors.yellow50 : AppColors.maroon50,
        foreground: address.isPrimary
            ? AppColors.gold500
            : AppColors.maroon700,
      ),
      title: Text(
        address.label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
      subtitle: Text(
        address.fullAddress,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.grey600),
      ),
      trailing: IconButton(
        onPressed: () => onEdit(existing: address),
        icon: const Icon(Icons.edit_outlined, color: AppColors.maroon700),
      ),
      onTap: () => onEdit(existing: address),
    );
  }
}

// =============================================================================
// HELPER
// =============================================================================

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.grey400),
          prefixIcon: const Icon(Icons.search, color: AppColors.grey400),
          filled: true,
          fillColor: AppColors.grey100,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: foreground, size: 20),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: const TextStyle(color: AppColors.grey600)),
    );
  }
}
