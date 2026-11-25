import 'package:dio/dio.dart';

import '../utils/app_log.dart';
import 'dio_client.dart';

/// Hasil pemeriksaan jaringan.
enum NetworkQuality {
  /// Cukup cepat untuk bertransaksi.
  baik,

  /// Tersambung, tapi lambat — permintaan berisiko habis waktu di tengah
  /// jalan.
  lambat,

  /// Tidak tersambung sama sekali.
  putus;

  bool get bolehTransaksi => this == baik;
}

/// Pemeriksa kualitas jaringan sesaat sebelum bertransaksi.
///
/// **Kenapa ada.** Checkout yang terkirim tapi responsnya tidak sampai adalah
/// kasus terburuk di aplikasi ini: server sudah membuat pesanan, aplikasi
/// mengira gagal, pembeli menekan Pesan sekali lagi — dan jadilah dua pesanan
/// dengan dua tagihan. Menahan pembeli beberapa detik jauh lebih murah
/// daripada memulangkan uang.
///
/// **Bukan pengganti penjagaan di server.** Pemeriksaan di sisi aplikasi
/// selalu bisa meleset: jaringan dapat memburuk sedetik setelah diperiksa.
/// Ini lapisan pertama; yang memastikan tidak ada pesanan ganda tetap kunci
/// idempoten di sisi backend.
class NetworkProbe {
  NetworkProbe(this._dio);

  final Dio _dio;

  static const String _tag = 'NET';

  /// Di atas ini jaringan dianggap terlalu lambat untuk bertransaksi.
  ///
  /// Sebagai pembanding, endpoint POS biasanya menjawab 70–250 ms. Ambang 2,5
  /// detik memberi ruang longgar untuk jaringan seluler yang sekadar biasa
  /// saja, dan hanya menahan yang benar-benar bermasalah.
  static const Duration ambangLambat = Duration(milliseconds: 2500);

  /// Berhenti menunggu di sini. Lebih pendek dari timeout umum (15 detik)
  /// karena tujuannya memang mengukur, bukan mengambil data.
  static const Duration batasTunggu = Duration(seconds: 6);

  /// Ukur kualitas jaringan dengan satu permintaan ringan.
  ///
  /// Memakai halaman pertama daftar pesanan dengan `limit=1` — endpoint yang
  /// sudah dipakai aplikasi, ber-Bearer, dan responsnya kecil.
  Future<NetworkQuality> check() async {
    final mulai = DateTime.now();
    try {
      await _dio.get<dynamic>(
        '/pos/app/v1/orders',
        queryParameters: const {'status': 'active', 'page': 1, 'limit': 1},
        options: Options(
          sendTimeout: batasTunggu,
          receiveTimeout: batasTunggu,
        ),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      // Tidak ada jawaban sama sekali: putus atau habis waktu.
      if (status == null) {
        AppLog.warn(_tag, 'pemeriksaan jaringan: PUTUS', detail: e.type.name);
        return NetworkQuality.putus;
      }

      // Server terjangkau tapi sedang bermasalah. Diperlakukan sama dengan
      // putus: melanjutkan checkout ke server yang sedang gagal hanya
      // memindahkan kegagalannya ke langkah berikutnya, setelah pembeli
      // mengira pesanannya sedang diproses.
      if (status >= 500) {
        AppLog.warn(_tag, 'pemeriksaan jaringan: server galat $status');
        return NetworkQuality.putus;
      }

      // 4xx lain berarti perjalanan bolak-baliknya berhasil — itu yang sedang
      // diukur di sini. Contohnya `404 data kosong` untuk pembeli yang belum
      // punya pesanan sama sekali. Lanjut ke pengukuran waktu di bawah.
    } catch (e) {
      AppLog.warn(_tag, 'pemeriksaan jaringan gagal', detail: e.toString());
      return NetworkQuality.putus;
    }

    final lama = DateTime.now().difference(mulai);
    final hasil = lama > ambangLambat
        ? NetworkQuality.lambat
        : NetworkQuality.baik;
    AppLog.info(
      _tag,
      'pemeriksaan jaringan: ${hasil.name} (${lama.inMilliseconds}ms)',
      detail: 'ambang lambat ${ambangLambat.inMilliseconds}ms',
    );
    return hasil;
  }
}

/// Instance global siap pakai.
final NetworkProbe networkProbe = NetworkProbe(dio);
