/// Pesanan aplikasi customer (`/pos/app/v1/orders`).
///
/// Bentuknya sama untuk hasil checkout, detail pesanan, dan pembatalan; daftar
/// pesanan memakai bentuk ringkas tanpa rincian item.
library;

import '../../core/config/app_features.dart';
import '../../core/utils/wita.dart';
import '../api/payment_api.dart';
import 'checkout_result.dart';

/// Status pesanan. Untuk **tampilan** pakai [Order.statusLabel] dari server;
/// enum ini untuk **logika** (mis. tombol Batalkan hanya saat `app_pending`).
enum OrderStatus {
  /// Tagihan sudah dibuat, **pembayaran belum lunas**.
  ///
  /// Inilah keadaan pesanan yang ditinggalkan pembeli di tengah pembayaran.
  /// Pesanan POS-nya belum terbentuk, jadi belum ada id numerik dan
  /// `GET /orders/:id` belum bisa dipakai — yang bisa dilakukan hanya
  /// melanjutkan pembayarannya.
  ///
  /// Server pernah menyebutnya `pending` (respons checkout) dan
  /// `menunggu_pembayaran` (daftar pesanan) untuk keadaan yang sama, jadi
  /// keduanya diterima.
  pending('pending', {'menunggu_pembayaran', 'waiting_payment'}),

  /// Sudah checkout, belum diambil/dibayar di outlet.
  appPending('app_pending'),

  /// Sudah lunas, pesanan sedang disiapkan outlet.
  ///
  /// Dikenali dari dokumen push backend (status `app_paid` → judul "Pesanan
  /// sedang disiapkan").
  appPaid('app_paid'),

  /// Sudah lunas, tetapi outlet menandai satu atau lebih item habis — pembeli
  /// perlu memilih pengganti sebelum pesanan disiapkan.
  ///
  /// **Belum dikirim server.** Status ini ditempelkan aplikasi sendiri dari
  /// `itemSwapStore` (lihat `data/item_swap_store.dart`) selama modul Ganti
  /// Item masih tiruan.
  perluTindakan('perlu_tindakan'),

  /// Kasir sudah menandai pesanan siap diambil (push "Pesanan siap diambil").
  appReady('app_ready'),

  /// Sudah diambil & dibayar di outlet (kasir serah terima).
  active('active'),

  /// Dibatalkan pembeli atau kasir.
  appCancelled('app_cancelled'),

  /// Dibatalkan lewat mekanisme POS.
  voided('voided'),

  /// Status baru yang belum dikenal aplikasi — diperlakukan sebagai selesai.
  unknown('');

  const OrderStatus(this.code, [this.aliases = const {}]);

  final String code;

  /// Ejaan lain yang dipakai server untuk keadaan yang sama.
  ///
  /// Ada karena satu keadaan bisa disebut berbeda antar-endpoint. Status yang
  /// tidak dikenali jatuh ke [unknown] dan diperlakukan sebagai selesai —
  /// akibatnya pesanan yang sebenarnya masih berjalan bisa lenyap dari tab
  /// Pesanan, jadi ejaan baru lebih baik didaftarkan di sini.
  final Set<String> aliases;

  static OrderStatus fromCode(Object? raw) {
    final code = raw?.toString().trim().toLowerCase();
    if (code == null || code.isEmpty) return unknown;
    for (final s in values) {
      if (s == unknown) continue;
      // TODO(ganti-item): hapus gate saat modul dirilis
      if (s == perluTindakan && !kFiturGantiItem) continue;
      if (s.code == code || s.aliases.contains(code)) return s;
    }
    return unknown;
  }

  /// Masih berjalan → tampil di tab Pesanan.
  ///
  /// Termasuk pesanan yang sudah lunas tapi belum diserahkan: selama roti
  /// belum ada di tangan pembeli, pesanannya belum selesai.
  bool get isActive =>
      this == pending ||
      this == appPending ||
      this == appPaid ||
      this == perluTindakan ||
      this == appReady;

  /// Pembayarannya belum selesai — pembeli masih bisa (dan perlu) melunasi.
  bool get isAwaitingPayment => this == pending;

  /// Sudah dibayar, tinggal menunggu/mengambil di outlet.
  bool get isPaid =>
      this == appPaid || this == perluTindakan || this == appReady;

  /// Ada item habis yang menunggu keputusan pembeli.
  bool get needsAction => this == perluTindakan;

  /// Kasir sudah menyatakan pesanan siap diambil.
  bool get isReady => this == appReady;

  /// Sudah tuntas/batal → tampil di tab Riwayat.
  bool get isDone => !isActive;

  bool get isCancelled => this == appCancelled || this == voided;

  /// Hanya pesanan `app_pending` yang boleh dibatalkan pembeli.
  bool get canCancel => this == appPending;
}

/// Sebuah pesanan.
class Order {
  const Order({
    required this.id,
    required this.documentNumber,
    required this.outletId,
    required this.outletName,
    required this.status,
    required this.statusLabel,
    required this.totalAmount,
    required this.itemCount,
    this.pickupAt,
    this.createdAt,
    this.keterangan = '',
    this.subtotalAmount = 0,
    this.discountAmount = 0,
    this.lines = const [],
    this.orderId = '',
    this.paymentMethod = '',
    this.provider = '',
    this.chargePath = '',
    this.expiresAt,
    this.charges,
    this.amountFee = 0,
  });

  final int id;

  /// Nomor yang disebutkan pembeli ke kasir saat mengambil pesanan.
  final String documentNumber;

  final int outletId;
  final String outletName;
  final OrderStatus status;

  /// Label status siap tampil dari server (mis. "Menunggu diambil").
  final String statusLabel;

  final int totalAmount;
  final int itemCount;

  /// Rencana ambil — jam dinding WITA (lihat `core/utils/wita.dart`).
  final DateTime? pickupAt;

  /// Waktu pesanan dibuat — jam dinding WITA.
  final DateTime? createdAt;

  final String keterangan;
  final int subtotalAmount;
  final int discountAmount;

  /// Rincian item. Kosong pada respons daftar pesanan.
  final List<OrderLine> lines;

  /// Nomor pesanan versi gateway (`order_id`), dipakai saat melanjutkan
  /// pembayaran. Jatuh balik ke [documentNumber] bila server tidak
  /// mengirimnya — keduanya bernilai sama pada alur bayar-dulu.
  final String orderId;

  /// Metode & penyedia pembayaran yang dipilih saat checkout.
  final String paymentMethod;
  final String provider;

  /// Endpoint charge dari server, relatif terhadap `/payment/api/v2`.
  final String chargePath;

  /// Batas waktu pembayaran dari server (waktu asli, bukan jam dinding).
  ///
  /// Penting saat pembayaran dilanjutkan: tanpa ini hitung mundur akan mulai
  /// dari 15 menit penuh lagi, padahal tagihannya dibuat beberapa menit lalu.
  final DateTime? expiresAt;

  /// Rincian biaya dari server. Hanya ada pada respons detail pesanan.
  final OrderCharges? charges;

  /// Biaya layanan versi ringkas (`amount_fee`) — dikirim daftar pesanan.
  ///
  /// Daftar tidak membawa objek [charges] yang lengkap, hanya satu angka ini.
  /// Sama seperti di detail, [totalAmount] **belum** memuatnya: pada respons
  /// nyata `total_amount: 16000` dengan `amount_fee: 160`, dan 160 itu persis
  /// 0,9% dari 16.000 ditambah PPN 11% — jadi 16.000 memang dasarnya, bukan
  /// hasil akhirnya.
  final int amountFee;

  /// True bila respons ini membawa rincian item (detail, bukan daftar).
  bool get hasLines => lines.isNotEmpty;

  /// Nilai pesanan sebelum biaya apa pun.
  ///
  /// Mendahulukan angka dari `charges` karena itulah dasar yang dipakai server
  /// saat menagih; `subtotal_amount` dipertahankan sebagai cadangan untuk
  /// respons yang belum membawa `charges`.
  int get displaySubtotal =>
      charges?.subtotal ?? (subtotalAmount > 0 ? subtotalAmount : totalAmount);

  /// Jumlah seluruh biaya yang dibebankan ke pembeli.
  ///
  /// Dua sumber, sesuai endpoint yang menjawabnya: detail pesanan mengirim
  /// rincian [charges], daftar pesanan mengirim satu angka [amountFee].
  /// Rincian didahulukan karena lebih lengkap.
  int get displayFee =>
      charges?.tagihanPembeli.fold<int>(0, (a, b) => a + b.amount) ??
      amountFee;

  /// Jumlah yang benar-benar dibayar pembeli.
  ///
  /// `total_amount` pada respons adalah nilai pesanan di POS — **belum**
  /// termasuk biaya gateway, jadi tidak pernah boleh ditampilkan sendirian
  /// sebagai total tagihan.
  int get displayTotal => charges?.paidByCustomer ?? (totalAmount + amountFee);

  /// Pembayarannya belum selesai — pembeli perlu melanjutkannya.
  bool get isAwaitingPayment => status.isAwaitingPayment;

  /// Nomor yang dipakai gateway pembayaran.
  String get payableOrderId =>
      orderId.trim().isNotEmpty ? orderId.trim() : documentNumber.trim();

  /// Bekal untuk membuka kembali halaman pembayaran pesanan ini.
  ///
  /// Halaman pembayaran bekerja dengan [CheckoutResult]; pesanan yang diambil
  /// dari daftar perlu dibentuk ulang ke sana. `charge` di gateway bersifat
  /// idempoten untuk `order_id` yang sama, jadi memanggilnya lagi akan
  /// mengembalikan tagihan yang sudah ada — bukan membuat tagihan kedua.
  CheckoutResult toCheckoutResult() => CheckoutResult(
    orderId: payableOrderId,
    outletId: outletId,
    status: status.code,
    statusLabel: statusLabel,
    // Yang ditagih gateway adalah nilai pesanan; biaya admin dihitung ulang
    // di halaman pembayaran lewat `.../calculate`.
    subtotalAmount: subtotalAmount > 0 ? subtotalAmount : totalAmount,
    paymentMethod: paymentMethod,
    provider: provider,
    chargePath: chargePath.trim().isNotEmpty
        ? chargePath
        : PaymentApi.defaultChargePath,
    expiresAt: expiresAt,
    pickupAt: pickupAt,
    createdAt: createdAt,
  );

  /// True bila pesanan ini benar-benar bisa dibuka & dimuat ulang.
  ///
  /// Tanpa [id] numerik, `GET /orders/:id` tidak bisa dipanggil — pesanan
  /// seperti itu hanya akan menghasilkan layar kosong, jadi jangan pernah
  /// diperlakukan sebagai hasil yang sah.
  bool get isUsable => id > 0 && documentNumber.trim().isNotEmpty;

  /// Salinan dengan beberapa nilai diganti — dipakai untuk menempelkan
  /// keadaan Ganti Item di atas data server.
  Order copyWith({
    OrderStatus? status,
    String? statusLabel,
    List<OrderLine>? lines,
  }) => Order(
    id: id,
    documentNumber: documentNumber,
    outletId: outletId,
    outletName: outletName,
    status: status ?? this.status,
    statusLabel: statusLabel ?? this.statusLabel,
    totalAmount: totalAmount,
    itemCount: itemCount,
    pickupAt: pickupAt,
    createdAt: createdAt,
    keterangan: keterangan,
    subtotalAmount: subtotalAmount,
    discountAmount: discountAmount,
    lines: lines ?? this.lines,
    orderId: orderId,
    paymentMethod: paymentMethod,
    provider: provider,
    chargePath: chargePath,
    expiresAt: expiresAt,
    charges: charges,
    amountFee: amountFee,
  );

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    return Order(
      id: _int(json['id']) ?? 0,
      documentNumber: (json['document_number'] ?? '').toString(),
      outletId: _int(json['outlet_id']) ?? 0,
      outletName: (json['outlet_name'] ?? '').toString(),
      status: OrderStatus.fromCode(json['status']),
      statusLabel: (json['status_label'] ?? '').toString(),
      totalAmount: _int(json['total_amount']) ?? 0,
      itemCount: _int(json['item_count']) ?? 0,
      pickupAt: parseWita(json['pickup_at']),
      createdAt: parseWita(json['created_at']),
      keterangan: (json['keterangan'] ?? '').toString(),
      subtotalAmount: _int(json['subtotal_amount']) ?? 0,
      discountAmount: _int(json['discount_amount']) ?? 0,
      // Dikirim pada alur bayar-dulu; dipakai untuk melanjutkan pembayaran
      // pesanan yang ditinggalkan di tengah jalan.
      orderId: (json['order_id'] ?? '').toString(),
      paymentMethod: (json['payment_method'] ?? '').toString(),
      provider: (json['provider'] ?? '').toString(),
      chargePath: (json['charge_path'] ?? '').toString(),
      // Waktu ASLI, bukan jam dinding WITA: dipakai menghitung sisa waktu
      // pembayaran, jadi harus dibandingkan dengan `DateTime.now()`.
      expiresAt: DateTime.tryParse((json['expires_at'] ?? '').toString()),
      amountFee: _int(json['amount_fee']) ?? 0,
      charges: json['charges'] is Map
          ? OrderCharges.fromJson(
              (json['charges'] as Map).cast<String, dynamic>(),
            )
          : null,
      lines: rawLines is List
          ? rawLines
                .whereType<Map>()
                .map((e) => OrderLine.fromJson(e.cast<String, dynamic>()))
                .toList(growable: false)
          : const [],
    );
  }
}

/// Satu baris item pesanan.
/// Satu baris biaya di luar harga menu (mis. biaya gateway pembayaran).
class OrderCharge {
  const OrderCharge({
    required this.label,
    required this.amount,
    this.chargeType = '',
    this.bearer = '',
  });

  /// Keterangan siap tampil dari server, mis. "Biaya QRIS (0,9% + PPN 11%)".
  /// Dipakai apa adanya — rumusnya sudah ditulis server, jangan dihitung ulang.
  final String label;

  final int amount;

  /// Jenis biaya, mis. `PAYMENT_FEE`.
  final String chargeType;

  /// Siapa yang menanggung: `CUSTOMER` atau pihak outlet.
  final String bearer;

  /// True bila biaya ini benar-benar dibebankan ke pembeli.
  bool get ditanggungPembeli => bearer.trim().toUpperCase() == 'CUSTOMER';

  factory OrderCharge.fromJson(Map<String, dynamic> json) => OrderCharge(
    label: (json['label'] ?? '').toString(),
    amount: _int(json['amount']) ?? 0,
    chargeType: (json['charge_type'] ?? '').toString(),
    bearer: (json['bearer'] ?? '').toString(),
  );
}

/// Rincian yang benar-benar dibayar pembeli (`charges` pada detail pesanan).
///
/// Sumber kebenaran untuk angka di layar: [subtotal] + biaya yang ditanggung
/// pembeli = [paidByCustomer]. Aplikasi tidak pernah menghitung sendiri —
/// biaya gateway berubah mengikuti metode pembayaran dan tarif yang hanya
/// diketahui server.
class OrderCharges {
  const OrderCharges({
    required this.subtotal,
    required this.paidByCustomer,
    this.items = const [],
  });

  final int subtotal;

  /// Total yang ditagihkan ke pembeli.
  final int paidByCustomer;

  final List<OrderCharge> items;

  /// Hanya biaya yang dibebankan ke pembeli.
  ///
  /// Biaya yang ditanggung outlet sengaja tidak ditampilkan: memperlihatkannya
  /// pada rincian pembeli membuat penjumlahannya tidak lagi cocok dengan
  /// [paidByCustomer] — terbaca seperti salah hitung.
  List<OrderCharge> get tagihanPembeli =>
      items.where((c) => c.ditanggungPembeli).toList(growable: false);

  factory OrderCharges.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return OrderCharges(
      subtotal: _int(json['subtotal']) ?? 0,
      paidByCustomer: _int(json['paid_by_customer']) ?? 0,
      items: raw is List
          ? raw
                .whereType<Map>()
                .map((e) => OrderCharge.fromJson(e.cast<String, dynamic>()))
                .toList(growable: false)
          : const [],
    );
  }
}

class OrderLine {
  const OrderLine({
    required this.menuId,
    required this.title,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.props = const [],
    this.tidakTersedia = false,
    this.pengganti = const [],
  });

  final int menuId;
  final String title;
  final int quantity;
  final int price;
  final int subtotal;

  /// Isi paket. `quantity` di sini sudah dikali jumlah paket.
  final List<OrderProp> props;

  /// Outlet menandai item ini habis setelah pesanan dibayar.
  final bool tidakTersedia;

  /// Item yang dipilih pembeli untuk menggantikan baris ini. Kosong bila
  /// belum diganti.
  final List<OrderLine> pengganti;

  bool get isPackage => props.isNotEmpty;

  /// Item habis yang sudah diganti — tidak lagi perlu tindakan.
  bool get sudahDiselesaikan => pengganti.isNotEmpty;

  /// Item habis yang masih menunggu keputusan pembeli.
  bool get menungguTindakan => tidakTersedia && !sudahDiselesaikan;

  OrderLine copyWith({
    bool? tidakTersedia,
    List<OrderLine>? pengganti,
  }) => OrderLine(
    menuId: menuId,
    title: title,
    quantity: quantity,
    price: price,
    subtotal: subtotal,
    props: props,
    tidakTersedia: tidakTersedia ?? this.tidakTersedia,
    pengganti: pengganti ?? this.pengganti,
  );

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    final rawProps = json['props'];
    return OrderLine(
      menuId: _int(json['menu_id']) ?? 0,
      title: (json['title'] ?? '').toString(),
      quantity: _int(json['quantity']) ?? 0,
      price: _int(json['price']) ?? 0,
      subtotal: _int(json['subtotal']) ?? 0,
      props: rawProps is List
          ? rawProps
                .whereType<Map>()
                .map((e) => OrderProp.fromJson(e.cast<String, dynamic>()))
                .toList(growable: false)
          : const [],
    );
  }
}

/// Komponen di dalam sebuah paket pesanan.
class OrderProp {
  const OrderProp({
    required this.menuId,
    required this.title,
    required this.quantity,
  });

  final int menuId;
  final String title;
  final int quantity;

  factory OrderProp.fromJson(Map<String, dynamic> json) => OrderProp(
    menuId: _int(json['menu_id']) ?? 0,
    title: (json['title'] ?? '').toString(),
    quantity: _int(json['quantity']) ?? 0,
  );
}

/// Sehalaman daftar pesanan beserta `metadata` paginasinya.
class OrderPage {
  const OrderPage({
    required this.orders,
    required this.page,
    required this.totalPage,
  });

  final List<Order> orders;
  final int page;
  final int totalPage;

  /// True bila masih ada halaman berikutnya.
  bool get hasMore => page < totalPage;

  factory OrderPage.fromResponse(Map<String, dynamic> body) {
    final data = body['data'];
    final meta = (body['metadata'] as Map?)?.cast<String, dynamic>();
    return OrderPage(
      orders: data is List
          ? data
                .whereType<Map>()
                .map((e) => Order.fromJson(e.cast<String, dynamic>()))
                .toList(growable: false)
          : const [],
      page: _int(meta?['page']) ?? 1,
      totalPage: _int(meta?['total_page']) ?? 1,
    );
  }
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}
