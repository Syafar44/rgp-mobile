import 'package:dio/dio.dart';

import '../core/config/env.dart';
import '../core/network/api_error.dart';
import '../core/network/dio_client.dart';
import '../core/utils/wita.dart';
import 'api/order_api.dart';
import 'models/order.dart';

/// Checkout & pesanan. Galat server (kode seperti `stok_tidak_tersedia`)
/// diterjemahkan menjadi [ApiException] berpesan Bahasa Indonesia siap tampil,
/// mengikuti tabel kode error pada dokumen API Aplikasi Customer.
class OrderRepository {
  OrderRepository(this._api);

  final OrderApi _api;

  /// Ubah keranjang outlet ini menjadi pesanan.
  ///
  /// [pickupAt] adalah jam dinding WITA; null = biarkan server memakai
  /// bawaannya (1 jam dari sekarang).
  Future<Order> checkout(
    int outletId, {
    DateTime? pickupAt,
    String? keterangan,
  }) async {
    _ensureConfigured();
    try {
      final res = await _api.checkout(
        outletId,
        pickupAt: pickupAt == null ? null : rfc3339Wita(pickupAt),
        keterangan: keterangan?.trim(),
      );
      return _parseOrder(res.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Daftar pesanan berjalan (`status=active`).
  Future<OrderPage> active({int page = 1, int limit = 10}) =>
      _list(status: 'active', page: page, limit: limit);

  /// Daftar pesanan selesai/batal (`status=history`).
  Future<OrderPage> history({int page = 1, int limit = 10}) =>
      _list(status: 'history', page: page, limit: limit);

  Future<Order> detail(int id) async {
    _ensureConfigured();
    try {
      final res = await _api.detail(id);
      return _parseOrder(res.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Batalkan pesanan. Hanya berlaku untuk pesanan `app_pending`.
  Future<Order> cancel(int id) async {
    _ensureConfigured();
    try {
      final res = await _api.cancel(id);
      return _parseOrder(res.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // --- Inti ------------------------------------------------------------------

  Future<OrderPage> _list({
    required String status,
    required int page,
    required int limit,
  }) async {
    _ensureConfigured();
    try {
      final res = await _api.list(status: status, page: page, limit: limit);
      final body = res.data;
      if (body is! Map) return const OrderPage(orders: [], page: 1, totalPage: 1);
      return OrderPage.fromResponse(body.cast<String, dynamic>());
    } on DioException catch (e) {
      // "data kosong" hanya berarti belum ada pesanan — bukan galat.
      if (_isEmptyData(e)) {
        return const OrderPage(orders: [], page: 1, totalPage: 1);
      }
      throw _mapError(e);
    }
  }

  Order _parseOrder(Object? body) {
    final data = body is Map ? body['data'] : null;
    if (data is Map) return Order.fromJson(data.cast<String, dynamic>());
    throw const ApiException('Respons pesanan tidak dikenali. Coba lagi.');
  }

  /// `404 data kosong` dipakai server untuk "tidak ada data", bukan kegagalan.
  bool _isEmptyData(DioException e) {
    if (e.response?.statusCode != 404) return false;
    final msg = serverMessage(e)?.trim().toLowerCase();
    return msg == 'data kosong';
  }

  // --- Galat -----------------------------------------------------------------

  ApiException _mapError(DioException e) {
    final network = networkErrorMessage(e);
    if (network != null) return ApiException(network);

    final status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      return ApiException(
        'Sesi Anda sudah berakhir. Silakan masuk lagi.',
        statusCode: status,
      );
    }

    final raw = serverMessage(e);
    return ApiException(
      _friendly(raw) ?? raw ?? 'Gagal memproses pesanan. Coba lagi.',
      statusCode: status,
    );
  }

  /// Terjemahkan kode galat server ke kalimat ramah. Null bila tak dikenal.
  String? _friendly(String? code) {
    final c = code?.trim().toLowerCase() ?? '';
    // Kode ini membawa status di belakangnya, mis.
    // `pesanan_tidak_bisa_dibatalkan: active`.
    if (c.startsWith('pesanan_tidak_bisa_dibatalkan')) {
      return 'Pesanan ini sudah tidak bisa dibatalkan.';
    }
    switch (c) {
      case 'stok_tidak_tersedia':
        return 'Stok sedang tidak tersedia. Kurangi jumlah atau pilih menu '
            'lain.';
      case 'menu_tidak_tersedia':
        return 'Ada menu yang sudah tidak dijual di outlet ini. Muat ulang '
            'keranjang Anda.';
      case 'keranjang_kosong':
        return 'Keranjang kosong atau sudah kedaluwarsa. Pilih menu lagi.';
      case 'pickup_at_tidak_valid':
        return 'Jam ambil tidak valid. Pilih jam lain.';
      case 'pickup_at_sudah_lewat':
        return 'Jam ambil sudah lewat. Pilih jam lain.';
      case 'pesanan_tidak_ditemukan':
        return 'Pesanan tidak ditemukan.';
      case 'outlet_not_found':
        return 'Outlet tidak ditemukan.';
      case 'data kosong':
        return 'Belum ada pesanan.';
      default:
        return null;
    }
  }

  void _ensureConfigured() {
    if (Env.isConfigured) return;
    throw const ApiException(
      'Konfigurasi server belum lengkap. Isi BASE_URL & API_KEY pada file '
      '.env lalu jalankan ulang aplikasi.',
    );
  }
}

/// Instance global siap pakai.
final OrderRepository orderRepository = OrderRepository(OrderApi(dio));
