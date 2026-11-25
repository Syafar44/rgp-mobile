import 'package:dio/dio.dart';

import '../../core/config/env.dart';

/// Endpoint layanan pembayaran (gateway Midtrans, Core API).
///
/// Autentikasinya **berbeda** dari endpoint lain di aplikasi ini: memakai
/// header `X-API-Key` dengan kunci sendiri ([Env.paymentApiKey]), bukan header
/// `apikey` maupun token Bearer.
class PaymentApi {
  PaymentApi(this._dio);

  final Dio _dio;

  Options get _auth => Options(headers: {'X-API-Key': Env.paymentApiKey});

  /// `GET /payment/api/v2/payment-methods` — daftar metode pembayaran aktif.
  Future<Response<dynamic>> methods() {
    return _dio.get<dynamic>('/payment/api/v2/payment-methods', options: _auth);
  }

  /// `POST /payment/api/v2/payment-methods/calculate` — hitung biaya admin.
  Future<Response<dynamic>> calculate({
    required String value,
    required int amount,
  }) {
    return _dio.post<dynamic>(
      '/payment/api/v2/payment-methods/calculate',
      data: {'value': value, 'amount': amount},
      options: _auth,
    );
  }

  /// Path pembuatan tagihan yang dipakai bila server tidak menyebutkannya.
  ///
  /// Kembali ke **Core API** (`/midtrans/charge`) setelah kanalnya aktif di
  /// akun production. Responsnya membawa nomor VA / gambar QR langsung, jadi
  /// halaman pembayaran menggambarnya sendiri tanpa webview.
  ///
  /// Hanya jaring pengaman: nilai dari server (`charge_path` pada respons
  /// checkout) selalu menang — itulah yang membuat gateway bisa diganti tanpa
  /// merilis aplikasi baru.
  ///
  /// **Satu `order_id`, satu endpoint.** Tagihan yang sudah dibuat lewat Snap
  /// tidak bisa dilanjutkan di Core API, dan sebaliknya; pesanan lama yang
  /// belum lunas perlu dibuat ulang.
  static const String defaultChargePath = '/midtrans/charge';

  /// Paksa semua tagihan lewat [defaultChargePath], abaikan `charge_path`
  /// dari server.
  ///
  /// Dipakai sekali, saat respons checkout masih menunjuk Core API padahal
  /// kanalnya belum aktif. Sekarang mati lagi: perpindahan gateway kembali
  /// sepenuhnya ditentukan server, tanpa perlu merilis aplikasi.
  static const bool paksaSnap = false;

  /// Path charge yang benar-benar dipanggil.
  ///
  /// [dariServer] adalah `charge_path` pada respons checkout. Kosong berarti
  /// server tidak menyebutkannya (mis. respons `GET /orders`).
  static String resolveChargePath(String dariServer) {
    if (paksaSnap) return defaultChargePath;
    final path = dariServer.trim();
    return path.isEmpty ? defaultChargePath : path;
  }

  /// `POST /payment/api/v2{chargePath}` — buat tagihan pembayaran.
  ///
  /// [chargePath] datang dari respons checkout (`charge_path`, mis.
  /// `/midtrans/charge`) supaya gateway bisa diganti server tanpa mengubah
  /// aplikasi.
  ///
  /// Wajib: [orderId] (maks 50 karakter, alfanumerik & dash), [amount]
  /// (minimal 1000), [paymentType], serta identitas pembeli. Sisanya
  /// bergantung metode — [bank] untuk `bank_transfer`, [billInfo1]/[billInfo2]
  /// untuk `echannel`, [tokenId] untuk `credit_card`, [acquirer] khusus
  /// `qris`.
  ///
  /// Masa berlaku tagihan selalu 15 menit dan tidak bisa diatur dari sini.
  Future<Response<dynamic>> charge({
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
  }) {
    final path = chargePath.startsWith('/') ? chargePath : '/$chargePath';
    return _dio.post<dynamic>(
      '/payment/api/v2$path',
      data: {
        'order_id': orderId,
        'amount': amount,
        'payment_type': paymentType,
        if (bank != null && bank.isNotEmpty) 'bank': bank,
        if (acquirer != null && acquirer.isNotEmpty) 'acquirer': acquirer,
        if (billInfo1 != null && billInfo1.isNotEmpty) 'bill_info1': billInfo1,
        if (billInfo2 != null && billInfo2.isNotEmpty) 'bill_info2': billInfo2,
        if (tokenId != null && tokenId.isNotEmpty) 'token_id': tokenId,
        'customer': {
          'name': customerName,
          'email': customerEmail,
          'phone': customerPhone,
        },
      },
      options: _auth,
    );
  }

  /// `GET /payment/api/v2/status/{order_id}` — status pembayaran terkini.
  ///
  /// Server memperbaruinya lewat webhook Midtrans, jadi aplikasi cukup
  /// menanyakan berkala.
  Future<Response<dynamic>> status(String orderId) {
    return _dio.get<dynamic>(
      '/payment/api/v2/status/${Uri.encodeComponent(orderId)}',
      options: _auth,
    );
  }
}
