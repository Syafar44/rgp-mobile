import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../config/env.dart';
import '../utils/app_log.dart';

/// Push notification lewat OneSignal (SDK v5).
///
/// Tiga tugasnya:
/// 1. menyalakan SDK sekali saat aplikasi start ([init]),
/// 2. mengikat perangkat ke akun yang sedang masuk ([syncUser]) supaya backend
///    bisa mengirim notifikasi ke satu pembeli tertentu, bukan ke semua orang,
/// 3. meneruskan ketukan notifikasi ke layar yang tepat ([onOpen]).
///
/// **Aman dimatikan.** Bila `ONESIGNAL_APP_ID` kosong di `.env`, seluruh method
/// di sini tidak melakukan apa pun — aplikasi tetap jalan tanpa push, sama
/// seperti perlakuan `Env.isConfigured` pada API. Ini juga yang membuat widget
/// test tidak perlu plugin native.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  static const String _tag = 'PUSH';

  bool _ready = false;

  /// External id yang sedang terpasang — dipakai agar [syncUser] tidak
  /// memanggil `login()` berulang untuk akun yang sama (mis. tiap `/me`
  /// menyegarkan profil).
  String? _boundExternalId;

  /// Dipasang oleh lapisan UI. Menerima ketukan notifikasi.
  ///
  /// Notifikasi bisa tiba sebelum handler terpasang — misalnya ketika aplikasi
  /// dingin dan justru DIBUKA oleh notifikasi itu. Karena itu ketukan yang
  /// datang lebih dulu disimpan di [_pending] lalu dikirim begitu handler ada.
  void Function(PushPayload payload)? get onOpen => _onOpen;
  void Function(PushPayload payload)? _onOpen;

  set onOpen(void Function(PushPayload payload)? handler) {
    _onOpen = handler;
    final pending = _pending;
    if (handler == null || pending == null) return;
    _pending = null;
    AppLog.info(_tag, 'ketukan tertunda diteruskan', detail: pending.toString());
    handler(pending);
  }

  PushPayload? _pending;

  bool get isReady => _ready;

  /// Nyalakan SDK. Panggil sekali dari `main()`.
  ///
  /// Sengaja TIDAK meminta izin notifikasi di sini: memunculkan dialog izin
  /// pada detik pertama aplikasi dibuka membuat pembeli menolak tanpa tahu
  /// gunanya. Izin diminta lewat [askPermission] setelah pembeli masuk.
  Future<void> init() async {
    if (_ready) return;
    if (!Env.isPushConfigured) {
      AppLog.warn(
        _tag,
        'ONESIGNAL_APP_ID kosong — push dimatikan',
        detail: 'Isi ONESIGNAL_APP_ID pada .env lalu jalankan ulang aplikasi.',
      );
      return;
    }

    try {
      // `verbose` membanjiri konsol; `warn` cukup untuk menelusuri masalah
      // tanpa menenggelamkan log jaringan yang sudah ada.
      if (AppLog.enabled) OneSignal.Debug.setLogLevel(OSLogLevel.warn);

      await OneSignal.initialize(Env.oneSignalAppId);
      OneSignal.Notifications.addClickListener(_handleClick);
      OneSignal.Notifications.addForegroundWillDisplayListener(_handleForeground);

      _ready = true;
      AppLog.info(
        _tag,
        'OneSignal siap',
        detail: 'app_id=${Env.oneSignalAppId} '
            'izin=${OneSignal.Notifications.permission}',
      );
    } catch (e) {
      // Push adalah pelengkap. Gagal menyalakannya tidak boleh menggagalkan
      // start aplikasi.
      AppLog.error(_tag, 'gagal menyalakan OneSignal', detail: e.toString());
    }
  }

  /// Minta izin notifikasi bila belum pernah diberikan.
  ///
  /// [fallbackToSettings] membuka halaman Pengaturan bila izin sudah pernah
  /// ditolak permanen — biarkan false untuk permintaan otomatis, dan pakai
  /// true hanya bila pembeli sendiri yang menyalakan lewat tombol.
  Future<bool> askPermission({bool fallbackToSettings = false}) async {
    if (!_ready) return false;
    try {
      if (OneSignal.Notifications.permission) return true;
      final granted = await OneSignal.Notifications.requestPermission(
        fallbackToSettings,
      );
      AppLog.info(
        _tag,
        'izin notifikasi: ${granted ? 'diberikan' : 'ditolak'}',
        // Id langganan ini yang dipakai tim backend untuk menguji kirim ke
        // satu HP tertentu dari dashboard OneSignal.
        detail: 'subscription_id=${OneSignal.User.pushSubscription.id}',
      );
      return granted;
    } catch (e) {
      AppLog.error(_tag, 'gagal meminta izin', detail: e.toString());
      return false;
    }
  }

  /// Ikat perangkat ini ke pembeli yang sedang masuk.
  ///
  /// `external_id` SELALU diambil dari `GET /pos/app/v1/push_identity`, tidak
  /// pernah disusun sendiri dan tidak pernah disimpan ke penyimpanan lokal:
  /// nilainya dibuat server dan bisa berubah bila kunci di sana diganti.
  /// Karena itu method ini dipanggil setiap aplikasi dibuka/kembali ke depan
  /// dalam keadaan sudah masuk, bukan hanya sekali setelah login.
  ///
  /// Gagal = didiamkan. Push adalah pelengkap; pembeli tidak boleh terhambat
  /// karenanya.
  /// [force] mengabaikan cache sesi dan memanggil `OneSignal.login()` lagi
  /// walau nilainya sama — dipakai tombol "Tautkan ulang" di halaman diagnosa.
  Future<void> linkToBuyer({bool force = false}) async {
    // Setiap jalur keluar di bawah ini dicatat. Penautan yang gagal diam-diam
    // adalah persis alasan backend bisa melapor "external_id belum tersimpan"
    // tanpa jejak apa pun di aplikasi.
    if (!_ready) {
      AppLog.warn(
        _tag,
        'penautan dilewati — SDK belum siap',
        detail: Env.isPushConfigured
            ? 'OneSignal.initialize() gagal; lihat baris galat sebelumnya.'
            : 'ONESIGNAL_APP_ID kosong di .env.',
      );
      return;
    }

    AppLog.info(_tag, 'meminta external_id ke /pos/app/v1/push_identity…');
    final externalId = await _fetchExternalId?.call();
    final id = externalId?.trim() ?? '';
    if (id.isEmpty) {
      AppLog.warn(
        _tag,
        'penautan dibatalkan — external_id tidak didapat',
        detail: 'Lihat baris sebelumnya untuk sebabnya (HTTP/galat jaringan). '
            'Perangkat TIDAK tertaut; backend tidak akan menemukannya.',
      );
      return;
    }

    // `_boundExternalId` hanya cache dalam memori satu sesi untuk menghindari
    // panggilan berulang yang percuma — bukan pengganti pengambilan dari
    // endpoint, yang tetap dilakukan di atas setiap kali.
    if (!force && _boundExternalId == id) {
      AppLog.info(
        _tag,
        'external_id tidak berubah — login() dilewati',
        detail: 'nilai=${redact(id)} (pakai "Tautkan ulang" untuk memaksa)',
      );
      return;
    }

    try {
      await OneSignal.login(id);
      _boundExternalId = id;

      // Verifikasi: baca kembali dari SDK. Tanpa ini, `login()` yang tidak
      // berefek apa-apa tetap terlihat "berhasil" di log.
      final terpasang = await OneSignal.User.getExternalId();
      final cocok = terpasang?.trim() == id;

      // `onesignal_id` hanya berguna untuk menelusuri masalah, dan
      // mengambilnya berarti satu panggilan lagi ke SDK. Di rilis log-nya
      // dibuang, jadi jangan bekerja untuk hasil yang tidak dipakai.
      final detail = AppLog.enabled
          ? 'dikirim=${redact(id)} '
                'terbaca=${terpasang == null ? '(kosong)' : redact(terpasang)} '
                'onesignal_id=${await OneSignal.User.getOnesignalId()} '
                'subscription_id=${OneSignal.User.pushSubscription.id}'
          : null;

      if (cocok) {
        AppLog.info(_tag, 'perangkat tertaut ke pembeli', detail: detail);
      } else {
        AppLog.error(
          _tag,
          'login() jalan TAPI external_id tidak tersimpan di SDK',
          detail: '$detail — inilah yang membuat backend tidak menemukannya.',
        );
        // Jangan simpan cache untuk nilai yang ternyata tidak terpasang,
        // supaya percobaan berikutnya benar-benar mencoba lagi.
        _boundExternalId = null;
      }
    } catch (e) {
      AppLog.error(_tag, 'OneSignal.login gagal', detail: e.toString());
    }
  }

  /// Keadaan push saat ini, apa adanya dari SDK — bahan halaman diagnosa.
  ///
  /// Sengaja membaca ulang dari OneSignal (bukan dari variabel aplikasi) supaya
  /// yang tampil adalah kenyataan di perangkat, bukan apa yang aplikasi kira.
  Future<Map<String, String>> diagnostics() async {
    final appId = Env.oneSignalAppId;
    if (!_ready) {
      return {
        'App ID (.env)': appId.isEmpty ? '(kosong)' : appId,
        'SDK siap': 'TIDAK',
        'Sebab': appId.isEmpty
            ? 'ONESIGNAL_APP_ID kosong di .env'
            : 'initialize() gagal — lihat Log Aplikasi, tag PUSH',
      };
    }

    String isi(String? v) => (v == null || v.trim().isEmpty) ? '(kosong)' : v;

    return {
      'App ID (.env)': appId,
      'SDK siap': 'ya',
      'Izin notifikasi': OneSignal.Notifications.permission ? 'ya' : 'TIDAK',
      'External ID di SDK': isi(await OneSignal.User.getExternalId()),
      'External ID terakhir dikirim': isi(_boundExternalId),
      'OneSignal ID': isi(await OneSignal.User.getOnesignalId()),
      'Subscription ID': isi(OneSignal.User.pushSubscription.id),
      'Langganan aktif':
          OneSignal.User.pushSubscription.optedIn == true ? 'ya' : 'TIDAK',
    };
  }

  /// `external_id` yang seharusnya dipakai, langsung dari server — untuk
  /// dibandingkan dengan yang benar-benar terpasang di SDK.
  Future<String?> serverExternalId() async => _fetchExternalId?.call();

  /// Lepas perangkat dari akun. Wajib saat pembeli keluar — tanpa ini, HP yang
  /// dipakai bergantian tetap menerima push pesanan akun sebelumnya.
  Future<void> unlink() async {
    if (!_ready) return;
    // Sengaja TIDAK memeriksa `_boundExternalId` dulu: cache itu kosong tiap
    // aplikasi baru dijalankan, sedangkan tautan di SDK bertahan antar-sesi.
    // Memeriksanya lebih dulu membuat pembeli yang keluar setelah membuka
    // ulang aplikasi tetap tertaut — HP yang dipakai bergantian akan menerima
    // push pesanan akun sebelumnya.
    try {
      await OneSignal.logout();
      _boundExternalId = null;
      AppLog.info(
        _tag,
        'perangkat dilepas dari akun',
        detail: 'external_id di SDK sekarang: '
            '${await OneSignal.User.getExternalId() ?? '(kosong)'}',
      );
    } catch (e) {
      AppLog.error(_tag, 'OneSignal.logout gagal', detail: e.toString());
    }
  }

  /// Pengambil `external_id` dari server.
  ///
  /// Disuntikkan dari luar (lihat `main.dart`) supaya lapisan `core` tidak
  /// bergantung pada `data` — arah ketergantungan di project ini selalu
  /// `data` → `core`.
  Future<String?> Function()? _fetchExternalId;

  set fetchExternalId(Future<String?> Function()? fetcher) =>
      _fetchExternalId = fetcher;

  /// Notifikasi terakhir yang tiba selagi aplikasi terbuka.
  ///
  /// Sengaja berupa [ValueNotifier], bukan satu callback: beberapa layar perlu
  /// ikut menyegarkan diri sekaligus (bilah pesanan aktif, daftar Pesanan,
  /// halaman status) supaya tak ada yang menampilkan status basi — persis yang
  /// diminta dokumen backend.
  final ValueNotifier<PushPayload?> lastForeground =
      ValueNotifier<PushPayload?>(null);

  /// Id langganan push perangkat ini — berguna saat backend perlu menguji
  /// kirim ke satu HP tertentu.
  String? get subscriptionId =>
      _ready ? OneSignal.User.pushSubscription.id : null;

  void _handleClick(OSNotificationClickEvent event) {
    final payload = PushPayload.fromNotification(event.notification);
    AppLog.info(_tag, 'notifikasi diketuk', detail: payload.toString());

    final handler = _onOpen;
    if (handler == null) {
      // Aplikasi kemungkinan baru dingin-start karena ketukan ini.
      _pending = payload;
      AppLog.info(_tag, 'handler belum siap — ketukan ditahan dulu');
      return;
    }
    handler(payload);
  }

  void _handleForeground(OSNotificationWillDisplayEvent event) {
    // Notifikasi dibiarkan tampil apa adanya (tidak memanggil
    // `preventDefault`), tapi datanya dipakai untuk menyegarkan layar yang
    // sedang terbuka.
    final payload = PushPayload.fromNotification(event.notification);
    AppLog.info(
      _tag,
      'notifikasi masuk (aplikasi terbuka)',
      detail: payload.toString(),
    );
    lastForeground.value = payload;
  }
}

/// Isi notifikasi yang dipakai aplikasi untuk menentukan layar tujuan.
///
/// Dibaca dari `additionalData` pada payload OneSignal. Kontrak backend
/// (dokumen "Push Notification Pesanan via OneSignal", bagian 5):
///
/// ```json
/// { "order_id": 123, "status": "app_ready" }
/// ```
///
/// [status] hanya petunjuk — pesanan bisa saja sudah berubah lagi saat push
/// diketuk, jadi status sebenarnya SELALU diambil ulang dari
/// `GET /pos/app/v1/orders/:id`. Begitu pula [title]/[body]: teksnya tidak
/// pernah ditampilkan ulang di dalam aplikasi.
class PushPayload {
  const PushPayload({
    this.type = '',
    this.status = '',
    this.orderId = 0,
    this.documentNumber = '',
    this.title = '',
    this.body = '',
  });

  /// Jenis notifikasi bila backend mengirimkannya. Saat ini semua push yang
  /// dikirim server adalah tentang pesanan, jadi biasanya kosong.
  final String type;

  /// `app_paid` (sedang disiapkan) atau `app_ready` (siap diambil).
  final String status;

  final int orderId;
  final String documentNumber;

  final String title;
  final String body;

  /// True bila notifikasi ini tentang sebuah pesanan.
  bool get isOrder =>
      type == 'order' ||
      orderId > 0 ||
      documentNumber.isNotEmpty ||
      status.startsWith('app_');

  /// True bila halaman status pesanan benar-benar bisa dimuat.
  ///
  /// Tanpa ini, ketukan bisa berakhir di halaman kosong — persis masalah yang
  /// dihindari [orderId] > 0 pada alur pembayaran.
  bool get canOpenOrder => orderId > 0;

  factory PushPayload.fromNotification(OSNotification notification) =>
      PushPayload.fromData(
        notification.additionalData,
        title: notification.title ?? '',
        body: notification.body ?? '',
      );

  /// Baca `additional_data` apa adanya.
  ///
  /// Terpisah dari [fromNotification] supaya kontrak payload bisa diuji tanpa
  /// menyalakan SDK — isinya datang dari backend dan paling rawan berubah.
  factory PushPayload.fromData(
    Map<String, dynamic>? data, {
    String title = '',
    String body = '',
  }) {
    final d = data ?? const <String, dynamic>{};
    return PushPayload(
      type: (d['type'] ?? '').toString().trim().toLowerCase(),
      status: (d['status'] ?? '').toString().trim().toLowerCase(),
      // Nama kunci belum seragam di sisi backend, jadi beberapa ejaan yang
      // masuk akal diterima sekaligus.
      orderId:
          _int(d['order_id']) ??
          _int(d['orders_id']) ??
          _int(d['pos_orders_id']) ??
          0,
      documentNumber: (d['document_number'] ?? d['order_number'] ?? '')
          .toString()
          .trim(),
      title: title,
      body: body,
    );
  }

  @override
  String toString() => 'order_id=$orderId status=$status '
      '${type.isEmpty ? '' : 'type=$type '}'
      '${documentNumber.isEmpty ? '' : 'doc=$documentNumber '}'
      'judul="$title"';
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

/// Instance global siap pakai (sejalan dengan `authStore`, `orderStore`).
final PushService pushService = PushService.instance;
