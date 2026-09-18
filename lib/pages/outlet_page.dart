import 'package:flutter/material.dart';

import '../core/network/api_error.dart';
import '../core/theme/app_colors.dart';
import '../data/location_service.dart';
import '../data/models/outlet.dart';
import '../data/outlet_repository.dart';
import '../widgets/app_top_bar.dart';

// Re-export agar konsumen (Beranda/Menu/Keranjang/Checkout) cukup mengimpor
// halaman ini untuk mendapatkan tipe [Outlet].
export '../data/models/outlet.dart';

/// Halaman pemilihan **Outlet Panglima**.
///
/// Saat dibuka: minta izin lokasi → ambil lat/long perangkat → panggil
/// `POST /pos/app/v1/outlets/nearby` untuk daftar outlet terdekat.
/// Mengembalikan [Outlet] yang dipilih lewat `Navigator.pop`.
class OutletPage extends StatefulWidget {
  const OutletPage({super.key});

  @override
  State<OutletPage> createState() => _OutletPageState();
}

class _OutletPageState extends State<OutletPage> {
  bool _loading = true;
  String? _error;
  List<Outlet> _outlets = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Minta lokasi lalu ambil outlet terdekat.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pos = await locationService.getCurrentPosition();
      final outlets = await outletRepository.nearby(
        lat: pos.latitude,
        long: pos.longitude,
        limit: 15,
      );
      if (!mounted) return;
      setState(() {
        _outlets = outlets;
        _loading = false;
      });
    } on LocationException catch (e) {
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
      appBar: const AppTopBar(title: 'Outlet Panglima'),
      body: Column(
        children: [
          _SearchField(
            hint: 'Cari outlet',
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const _Loading();
    if (_error != null) return _ErrorState(message: _error!, onRetry: _load);

    final q = _query.toLowerCase();
    final list = _outlets
        .where(
          (o) =>
              o.name.toLowerCase().contains(q) ||
              o.address.toLowerCase().contains(q),
        )
        .toList();
    if (list.isEmpty) {
      return const _EmptyText('Outlet tidak ditemukan');
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.maroon700,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: list.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 68, endIndent: 16),
        itemBuilder: (context, i) => _OutletTile(
          outlet: list[i],
          onTap: () => Navigator.pop<Outlet>(context, list[i]),
        ),
      ),
    );
  }
}

// =============================================================================
// ITEM OUTLET
// =============================================================================

class _OutletTile extends StatelessWidget {
  const _OutletTile({required this.outlet, required this.onTap});

  final Outlet outlet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: const _RoundIcon(
        icon: Icons.storefront,
        background: AppColors.maroon50,
        foreground: AppColors.maroon700,
      ),
      title: Text(
        outlet.name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
      subtitle: Text(
        outlet.address,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.grey600),
      ),
      trailing: outlet.distanceKm == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.maroon50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${outlet.distanceKm!.toStringAsFixed(2)} km',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.maroon700,
                ),
              ),
            ),
      onTap: onTap,
    );
  }
}

// =============================================================================
// STATE: memuat & galat
// =============================================================================

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.maroon700),
          SizedBox(height: 16),
          Text(
            'Mencari outlet terdekat...',
            style: TextStyle(color: AppColors.grey600),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 56,
              color: AppColors.grey300,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.maroon700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HELPER
// =============================================================================

/// Kolom pencarian membulat.
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
