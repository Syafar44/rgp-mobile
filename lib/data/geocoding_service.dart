import 'package:dio/dio.dart';

/// Hasil reverse-geocoding (koordinat → alamat).
class GeoAddress {
  const GeoAddress({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lon,
  });

  /// Alamat lengkap (Nominatim `display_name`).
  final String displayName;

  /// Nama singkat (jalan / tempat) untuk saran "Nama Alamat".
  final String shortName;

  final double lat;
  final double lon;
}

/// Reverse-geocoding memakai Nominatim (OpenStreetMap).
///
/// Menerjemahkan lat/long menjadi alamat Bahasa Indonesia. Sesuai kebijakan
/// Nominatim: sertakan `User-Agent`, dan jangan panggil lebih dari 1x/detik
/// (di UI sudah di-debounce saat peta berhenti bergeser).
class GeocodingService {
  GeocodingService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://nominatim.openstreetmap.org',
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 12),
            headers: {
              'User-Agent': 'RotiGembungPanglimaApp/1.0 (kontak@panglima.id)',
            },
          ),
        );

  final Dio _dio;

  Future<GeoAddress?> reverse(double lat, double lon) async {
    try {
      final res = await _dio.get<dynamic>(
        '/reverse',
        queryParameters: {
          'format': 'jsonv2',
          'lat': lat,
          'lon': lon,
          'zoom': 18,
          'addressdetails': 1,
          'accept-language': 'id',
        },
      );
      final data = res.data;
      if (data is! Map) return null;

      final display = data['display_name']?.toString() ?? '';
      if (display.isEmpty) return null;

      String short = '';
      final addr = data['address'];
      if (addr is Map) {
        short = (addr['road'] ??
                addr['pedestrian'] ??
                addr['neighbourhood'] ??
                addr['suburb'] ??
                addr['village'] ??
                addr['amenity'] ??
                addr['city'] ??
                '')
            .toString();
      }
      if (short.isEmpty) short = display.split(',').first.trim();

      return GeoAddress(
        displayName: display,
        shortName: short,
        lat: lat,
        lon: lon,
      );
    } catch (_) {
      // Gagal jaringan / diluar cakupan — biarkan pemanggil pakai fallback.
      return null;
    }
  }
}

/// Instance global sederhana.
final GeocodingService geocodingService = GeocodingService();
