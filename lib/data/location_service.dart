import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Error lokasi dengan pesan ramah pengguna.
class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Ambil lokasi GPS perangkat (pola mengikuti project svp_app).
class LocationService {
  Future<LatLng> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'GPS tidak aktif. Aktifkan lokasi perangkat.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Izin lokasi ditolak.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Izin lokasi ditolak permanen. Aktifkan lewat Pengaturan.',
      );
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return LatLng(pos.latitude, pos.longitude);
  }
}

/// Instance global sederhana.
final LocationService locationService = LocationService();
