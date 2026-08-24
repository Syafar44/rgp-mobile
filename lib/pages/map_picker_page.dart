import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_colors.dart';
import '../data/geocoding_service.dart';
import '../data/location_service.dart';

/// Titik lokasi hasil pilih di peta (OpenStreetMap).
typedef PickedLocation = ({
  String title,
  String fullAddress,
  double lat,
  double lon,
});

/// Halaman pilih lokasi di peta OpenStreetMap.
///
/// Pin selalu di tengah layar; menggeser peta memindahkan titik. Saat peta
/// berhenti bergeser, koordinat titik tengah di-reverse-geocode (Nominatim)
/// menjadi alamat Bahasa Indonesia dan ditampilkan di kartu bawah.
class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  // Titik awal: sekitar Jl. Ir. H. Juanda, Samarinda.
  static const LatLng _initial = LatLng(-0.4926, 117.1449);

  final MapController _map = MapController();
  LatLng _center = _initial;
  GeoAddress? _address;
  bool _loading = true;
  Timer? _debounce;

  // Lokasi GPS diambil saat peta siap (onMapReady), bukan di initState.

  @override
  void dispose() {
    _debounce?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _center = camera.center;
    _scheduleReverse();
  }

  /// Reverse-geocode setelah peta diam ~700ms (hemat kuota Nominatim).
  ///
  /// Tidak memakai setState di sini agar aman dipanggil dari callback peta
  /// (menghindari "setState during build"); UI ter-update saat [_reverse] selesai.
  void _scheduleReverse() {
    _debounce?.cancel();
    _loading = true;
    _debounce = Timer(const Duration(milliseconds: 700), _reverse);
  }

  Future<void> _reverse() async {
    final target = _center;
    final result = await geocodingService.reverse(
      target.latitude,
      target.longitude,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _address = result ??
          GeoAddress(
            displayName:
                'Lokasi terpilih (${target.latitude.toStringAsFixed(5)}, '
                '${target.longitude.toStringAsFixed(5)})',
            shortName: 'Lokasi terpilih',
            lat: target.latitude,
            lon: target.longitude,
          );
    });
  }

  /// Ambil lokasi GPS perangkat lalu geser peta ke sana.
  Future<void> _goToCurrentLocation() async {
    if (mounted) setState(() => _loading = true);
    try {
      final pos = await locationService.getCurrentPosition();
      if (!mounted) return;
      _center = pos;
      _map.move(pos, 17);
      _scheduleReverse();
    } on LocationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      _scheduleReverse(); // reverse-geocode titik fallback saat ini
    } catch (_) {
      if (!mounted) return;
      _scheduleReverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Peta OpenStreetMap.
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _initial,
              initialZoom: 16,
              minZoom: 4,
              maxZoom: 19,
              onMapReady: _goToCurrentLocation,
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.panglima.roti_gembung_panglima_app',
                maxZoom: 19,
              ),
              const _Attribution(),
            ],
          ),

          // Pin tetap di tengah + tooltip.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    _Tooltip(),
                    SizedBox(height: 2),
                    Icon(
                      Icons.location_on,
                      color: AppColors.maroon700,
                      size: 46,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tombol kembali.
          Positioned(
            top: 0,
            left: 12,
            child: SafeArea(
              child: _CircleButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.pop(context),
              ),
            ),
          ),

          // Tombol recenter.
          Positioned(
            right: 16,
            bottom: 140,
            child: _CircleButton(
              icon: Icons.my_location,
              onTap: _goToCurrentLocation,
            ),
          ),

          // Kartu alamat terpilih.
          Positioned(left: 16, right: 16, bottom: 12, child: _addressCard()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _address == null ? null : _confirm,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Pilih Lokasi Ini'),
          ),
        ),
      ),
    );
  }

  void _confirm() {
    final a = _address!;
    Navigator.pop<PickedLocation>(context, (
      title: a.shortName,
      fullAddress: a.displayName,
      lat: a.lat,
      lon: a.lon,
    ));
  }

  Widget _addressCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.maroon50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on,
              color: AppColors.maroon700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _loading || _address == null
                ? Row(
                    children: const [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Menerjemahkan lokasi...',
                        style: TextStyle(color: AppColors.grey600),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _address!.shortName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _address!.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.grey600,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// KOMPONEN KECIL
// =============================================================================

class _Tooltip extends StatelessWidget {
  const _Tooltip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.maroon700,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Geser untuk pindah lokasi',
        style: TextStyle(
          color: AppColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: AppColors.textDark),
        ),
      ),
    );
  }
}

/// Atribusi wajib OpenStreetMap.
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(right: 4, bottom: 84),
        child: ColoredBox(
          color: Color(0xB3FFFFFF),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: Text(
              '© OpenStreetMap',
              style: TextStyle(fontSize: 10, color: AppColors.grey600),
            ),
          ),
        ),
      ),
    );
  }
}
