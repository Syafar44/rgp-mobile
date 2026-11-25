import 'package:dio/dio.dart';

import '../core/utils/app_log.dart';
import '../core/config/env.dart';
import '../core/network/api_error.dart';
import '../core/network/dio_client.dart';
import '../core/utils/wita.dart';
import 'api/order_api.dart';
import 'item_swap_store.dart';
import 'models/checkout_result.dart';
import 'models/order.dart';

/// Checkout & pesanan. Galat server (kode seperti `stok_tidak_tersedia`)
/// diterjemahkan menjadi [ApiException] berpesan Bahasa Indonesia siap tampil,
/// mengikuti tabel kode error pada dokumen API Aplikasi Customer.
class OrderRepository {
  OrderRepository(this._api);

  final OrderApi _api;

  /// Ubah keranjang outlet ini menjadi pesanan.
  ///
  /// [paymentMethod] wajib diisi dengan `value` metode pembayaran (mis.
  /// `qris`). [pickupAt] adalah jam dinding WITA; null = biarkan server
  /// memakai bawaannya (1 jam dari sekarang).
  Future<CheckoutResult> checkout(
    int outletId, {
    required String paymentMethod,
    DateTime? pickupAt,
    String? keterangan,
  }) async {
    _ensureConfigured();

    final sentPickup = pickupAt == null ? null : rfc3339Wita(pickupAt);
    // Jejak zona waktu: selisih jam paling sering berasal dari HP yang
    // zonanya bukan WITA, bukan dari salah hitung. Catat ketiganya supaya
    // arah selisihnya terbaca langsung dari log.
    final device = DateTime.now();
    AppLog.info(
      'CHECKOUT',
      'waktu — HP ${_clock(device)} (UTC${_offset(device)}) · '
          'WITA ${_clock(nowWita())}',
      detail: sentPickup == null
          ? 'pickup_at tidak dikirim → server memakai bawaannya (1 jam dari '
                'sekarang)'
          : 'pickup_at dikirim: $sentPickup',
    );

    try {
      final res = await _api.checkout(
        outletId,
        paymentMethod: paymentMethod,
        pickupAt: sentPickup,
        keterangan: keterangan?.trim(),
      );
      final data = res.data is Map ? (res.data as Map)['data'] : null;
      if (data is! Map) {
        AppLog.error('CHECKOUT', 'respons tanpa objek `data`',
            detail: logTrim(res.data));
        throw const ApiException('Respons checkout tidak dikenali. Coba lagi.');
      }
      final result = CheckoutResult.fromJson(data.cast<String, dynamic>());
      AppLog.info(
        'CHECKOUT',
        'pesanan dibuat ${result.orderId}',
        detail: 'status=${result.status} provider=${result.provider} '
            'charge_path=${result.chargePath} '
            'subtotal=${result.subtotalAmount} '
            'pos_orders_id=${result.posOrderId}',
      );
      return result;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Daftar pesanan berjalan (`status=active`).
  ///
  /// Ditempeli keadaan Ganti Item (tiruan) — lihat [ItemSwapStore].
  Future<OrderPage> active({int page = 1, int limit = 10}) async =>
      itemSwapStore.overlayPage(
        await _list(status: 'active', page: page, limit: limit),
        riwayat: false,
      );

  /// Daftar pesanan selesai/batal (`status=history`).
  Future<OrderPage> history({int page = 1, int limit = 10}) async =>
      itemSwapStore.overlayPage(
        await _list(status: 'history', page: page, limit: limit),
        riwayat: true,
      );

  /// Cari pesanan berdasarkan nomornya (`document_number`).
  ///
  /// Dipakai untuk mengetahui apakah sebuah tagihan sudah lunas: selama belum
  /// dibayar, pesanan tidak muncul di `GET /orders` (`pos_orders_id` masih
  /// null). Begitu muncul, berarti pembayaran sudah masuk — dan barulah
  /// tersedia id numerik untuk membuka detailnya.
  ///
  /// Server belum menyediakan pencarian per nomor, jadi daftar ditelusuri
  /// halaman demi halaman; [maxPages] membatasi supaya tidak berlarut.
  Future<Order?> findByDocumentNumber(
    String documentNumber, {
    int maxPages = 3,
    int limit = 20,
  }) async {
    final target = documentNumber.trim().toLowerCase();
    if (target.isEmpty) return null;

    for (var page = 1; page <= maxPages; page++) {
      final result = await _list(status: '', page: page, limit: limit);
      AppLog.info(
        'ORDER',
        'cari "$documentNumber" di halaman $page — ${result.orders.length} baris',
        detail: result.orders
            .map((o) => 'id=${o.id} doc=${o.documentNumber} '
                'status=${o.status.code}')
            .join(' | '),
      );
      for (final order in result.orders) {
        if (order.documentNumber.trim().toLowerCase() != target) continue;
        // Baris yang cocok tapi tanpa id numerik tidak bisa dibuka detailnya.
        // Perlakukan seperti belum ketemu ketimbang mengembalikan pesanan
        // yang hanya akan tampil kosong di layar.
        if (order.isUsable) {
          AppLog.info('ORDER', 'ketemu & layak dipakai: id=${order.id}');
          return order;
        }
        AppLog.warn(
          'ORDER',
          'nomor cocok tapi TIDAK layak dipakai — diabaikan',
          detail: 'id=${order.id} (butuh > 0) '
              'doc="${order.documentNumber}" — daftar pesanan tidak '
              'mengirim id numerik yang bisa dipakai GET /orders/:id',
        );
        return null;
      }
      if (!result.hasMore) break;
    }
    AppLog.warn('ORDER', 'nomor "$documentNumber" tidak ada di daftar pesanan');
    return null;
  }

  Future<Order> detail(int id) async {
    // Pesanan buatan simulasi Ganti Item tidak ada di server.
    final tiruan = itemSwapStore.pesananTiruan(id);
    if (tiruan != null) return tiruan;

    _ensureConfigured();
    try {
      final res = await _api.detail(id);
      return itemSwapStore.overlay(_parseOrder(res.data));
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
    // Galat validator Go mentah, mis. "Key: 'AppOrderCheckoutReq.PaymentMethod'
    // Error:Field validation for 'PaymentMethod' failed on the 'required' tag".
    // Jangan pernah ditampilkan apa adanya ke pembeli.
    if (c.contains('field validation')) {
      if (c.contains('paymentmethod')) {
        return 'Metode pembayaran belum dipilih. Pilih salah satu lalu coba '
            'lagi.';
      }
      return 'Data pesanan tidak diterima server. Muat ulang halaman lalu '
          'coba lagi.';
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

  /// `HH:mm` untuk log.
  String _clock(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  /// Beda zona perangkat terhadap UTC, mis. `+7` (WIB) atau `+8` (WITA).
  String _offset(DateTime d) {
    final h = d.timeZoneOffset.inMinutes / 60;
    final sign = h < 0 ? '-' : '+';
    final abs = h.abs();
    return '$sign${abs == abs.roundToDouble() ? abs.toInt() : abs}';
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
