import 'package:dio/dio.dart';

import '../core/config/env.dart';
import '../core/network/api_error.dart';
import '../core/network/dio_client.dart';
import '../core/utils/app_log.dart';
import 'api/payment_api.dart';
import 'models/payment_charge.dart';
import 'models/payment_method.dart';

/// Layanan pembayaran (gateway Midtrans).
///
/// Pembungkus responsnya `{success, data}` — berbeda dari endpoint POS yang
/// memakai `{message, data}` — jadi parsing & galatnya ditangani terpisah.
class PaymentRepository {
  PaymentRepository(this._api);

  final PaymentApi _api;

  /// Metode yang BELUM aktif di akun Midtrans production.
  ///
  /// Memilihnya hanya menghasilkan halaman Snap kosong — pembeli mengira
  /// aplikasinya rusak. Disaring di sini, satu tempat, supaya halaman checkout
  /// maupun daftar "lihat semua" sama-sama bersih. Hapus dari daftar ini
  /// begitu tim backend mengabarkan metodenya sudah aktif.
  ///
  /// GoPay sengaja tidak diganti apa pun: QRIS pada daftar sudah bisa dipindai
  /// dari aplikasi GoPay, OVO, DANA, maupun m-banking.
  static const Set<String> _belumAktif = {'gopay', 'bca', 'credit_card'};

  /// Buang metode yang belum aktif dari [semua].
  ///
  /// Terpisah dari [methods] supaya aturannya bisa diuji tanpa server.
  static List<PaymentMethod> hanyaYangAktif(List<PaymentMethod> semua) => semua
      .where((m) => !_belumAktif.contains(m.value.trim().toLowerCase()))
      .toList(growable: false);

  /// Daftar metode pembayaran aktif. Kosong bila server tidak mengirim satu
  /// pun (bukan galat).
  Future<List<PaymentMethod>> methods() async {
    _ensureConfigured();
    try {
      final res = await _api.methods();
      final body = res.data;
      final list = body is Map ? body['data'] : body;
      if (list is! List) return const [];
      final semua = list
          .whereType<Map>()
          .map((e) => PaymentMethod.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);

      final dipakai = hanyaYangAktif(semua);

      if (dipakai.length != semua.length) {
        AppLog.info(
          'PAY',
          'metode disaring ${semua.length} → ${dipakai.length}',
          detail: 'disembunyikan karena belum aktif di Midtrans: '
              '${semua.map((m) => m.value).where(_belumAktif.contains).join(', ')}',
        );
      }
      return dipakai;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Hitung biaya admin untuk [amount] memakai metode [value].
  Future<PaymentCalculation> calculate({
    required String value,
    required int amount,
  }) async {
    _ensureConfigured();
    try {
      final res = await _api.calculate(value: value, amount: amount);
      return PaymentCalculation.fromJson(_dataOf(res.data));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Buat tagihan pembayaran untuk sebuah pesanan.
  ///
  /// [chargePath] diambil dari `charge_path` pada respons checkout.
  /// Mengirim ulang [orderId] yang sama dengan nominal & metode yang sama
  /// aman: server mengembalikan tagihan yang sudah ada, bukan membuat baru.
  Future<PaymentCharge> charge({
    required String chargePath,
    required String orderId,
    required int amount,
    required String paymentType,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String? bank,
    String? acquirer,
    String? billInfo1,
    String? billInfo2,
    String? tokenId,
  }) async {
    _ensureConfigured();
    // Satu tempat penentuan endpoint, supaya semua pemanggil (checkout baru
    // maupun "lanjutkan pembayaran") pasti memakai jalur yang sama — tagihan
    // terkunci ke satu endpoint per `order_id`.
    final path = PaymentApi.resolveChargePath(chargePath);
    if (path != chargePath.trim()) {
      AppLog.warn(
        'PAY',
        'charge_path server diabaikan → $path',
        detail: 'server mengirim "${chargePath.trim()}"; aplikasi memaksa Snap '
            '(PaymentApi.paksaSnap). Kembalikan ke false begitu backend '
            'mengirim charge_path yang benar.',
      );
    }
    try {
      final res = await _api.charge(
        chargePath: path,
        orderId: orderId,
        amount: amount,
        paymentType: paymentType,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        bank: bank,
        acquirer: acquirer,
        billInfo1: billInfo1,
        billInfo2: billInfo2,
        tokenId: tokenId,
      );
      return PaymentCharge.fromJson(_dataOf(res.data));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Status pembayaran terkini. Null bila tagihannya belum/tidak ada
  /// (`404 payment not found`) — bukan galat, tagihan mungkin baru dibuat.
  Future<PaymentStatus?> status(String orderId) async {
    _ensureConfigured();
    try {
      final res = await _api.status(orderId);
      return PaymentStatus.fromJson(_dataOf(res.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _mapError(e);
    }
  }

  Map<String, dynamic> _dataOf(Object? body) {
    final data = body is Map ? body['data'] : null;
    if (data is Map) return data.cast<String, dynamic>();
    throw const ApiException('Respons pembayaran tidak dikenali. Coba lagi.');
  }

  // --- Galat -----------------------------------------------------------------

  ApiException _mapError(DioException e) {
    final network = networkErrorMessage(e);
    if (network != null) return ApiException(network);

    final status = e.response?.statusCode;
    final raw = serverMessage(e);

    if (status == 401 || status == 403) {
      // Kunci pembayaran terpisah dari API_KEY biasa — pesan ini menunjuk ke
      // penyebab yang benar supaya tidak tertukar dengan sesi login kedaluwarsa.
      return ApiException(
        raw?.toLowerCase().contains('not yet activated') == true
            ? 'Kunci layanan pembayaran belum diaktifkan. Hubungi tim backend.'
            : 'Kunci layanan pembayaran tidak diterima server. Periksa '
                  'API_KEY_PAYMENT pada file .env.',
        statusCode: status,
      );
    }

    return ApiException(
      _friendly(raw) ?? raw ?? 'Gagal memproses pembayaran. Coba lagi.',
      statusCode: status,
    );
  }

  /// Terjemahkan galat charge ke kalimat yang bisa ditindaklanjuti pembeli.
  ///
  /// Pesan server menyertakan `order_id` dan istilah teknis, jadi jangan
  /// ditampilkan mentah-mentah.
  String? _friendly(String? raw) {
    final m = raw?.toLowerCase() ?? '';
    if (m.isEmpty) return null;

    if (m.contains('sedang diproses')) {
      return 'Pembayaran sedang diproses. Tunggu sebentar lalu coba lagi.';
    }
    if (m.contains('sudah dibayar')) {
      return 'Pesanan ini sudah dibayar.';
    }
    if (m.contains('sudah expire')) {
      return 'Tagihan sudah kedaluwarsa. Silakan buat pesanan baru.';
    }
    if (m.contains('tidak cocok dengan') ||
        m.contains('sudah ada dengan nominal') ||
        m.contains('sudah dibuat dengan metode')) {
      // Nominal atau metode berbeda dari tagihan yang sudah ada. Gateway
      // mengunci keduanya ke `order_id`, jadi satu-satunya jalan adalah
      // pesanan baru.
      return 'Tagihan untuk pesanan ini sudah dibuat dengan nominal atau '
          'metode lain. Silakan buat pesanan baru.';
    }
    // Snap & Core API tidak bisa saling melanjutkan `order_id` yang sama.
    // Terjadi bila tagihan dibuat sebelum backend berpindah ke Snap.
    if (m.contains('lewat core api') || m.contains('bukan snap')) {
      return 'Pesanan ini dibuat dengan cara pembayaran lama. Silakan buat '
          'pesanan baru.';
    }
    if (m.contains('payment channel is not activated')) {
      return 'Metode pembayaran ini sedang tidak aktif. Pilih metode lain.';
    }
    if (m.contains('bank field is required')) {
      return 'Pilih bank tujuan transfer terlebih dahulu.';
    }
    if (m.contains('bill_info')) {
      return 'Data tagihan Mandiri Bill belum lengkap.';
    }
    if (m.contains('token_id')) {
      return 'Data kartu belum lengkap.';
    }
    if (m.contains('alphanumeric characters and dashes')) {
      return 'Nomor pesanan tidak diterima gateway pembayaran.';
    }
    if (m.contains('invalid request body')) {
      return 'Data pembayaran tidak diterima server. Coba lagi.';
    }
    return null;
  }

  void _ensureConfigured() {
    if (Env.isPaymentConfigured) return;
    throw const ApiException(
      'Kunci layanan pembayaran belum diisi. Tambahkan API_KEY_PAYMENT pada '
      'file .env lalu jalankan ulang aplikasi.',
    );
  }
}

/// Instance global siap pakai.
final PaymentRepository paymentRepository = PaymentRepository(PaymentApi(dio));
