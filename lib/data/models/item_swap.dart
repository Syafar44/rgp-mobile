/// Ganti Item Tidak Tersedia — catatan penggantian per item pesanan.
///
/// Pesanan sudah dibayar, lalu outlet menandai satu atau lebih itemnya habis.
/// Karena uang sudah masuk, pembeli memilih pengganti dari outlet yang sama
/// — senilai atau lebih mahal, bukan lebih murah, karena belum ada refund.
/// Setiap item diselesaikan sendiri; pesanan baru lanjut disiapkan setelah
/// semuanya selesai.
///
/// **Masih tiruan** — belum ada endpoint. Keadaannya disimpan di HP oleh
/// `itemSwapStore` dan ditempelkan di atas data server lewat
/// [OrderSwap.applyTo].
library;

import 'order.dart';

/// Cara sebuah item habis diselesaikan.
///
/// Baru satu cara: refund belum tersedia, jadi setiap item habis harus
/// diganti. Tetap berupa enum agar data tersimpan tidak perlu diubah bila
/// cara lain menyusul.
enum SwapResolution {
  diganti('diganti');

  const SwapResolution(this.code);

  final String code;

  static SwapResolution? fromCode(Object? raw) {
    for (final r in values) {
      if (r.code == raw) return r;
    }
    return null;
  }
}

/// Satu produk yang dipilih pembeli sebagai pengganti.
class SwapPick {
  const SwapPick({
    required this.menuId,
    required this.title,
    required this.price,
    required this.quantity,
  });

  final int menuId;
  final String title;
  final int price;
  final int quantity;

  int get subtotal => price * quantity;

  Map<String, dynamic> toJson() => {
    'menu_id': menuId,
    'title': title,
    'price': price,
    'quantity': quantity,
  };

  factory SwapPick.fromJson(Map<String, dynamic> json) => SwapPick(
    menuId: _int(json['menu_id']),
    title: (json['title'] ?? '').toString(),
    price: _int(json['price']),
    quantity: _int(json['quantity']),
  );

  /// Bentuk baris pesanan, untuk ditampilkan di bawah item asalnya.
  OrderLine toLine() => OrderLine(
    menuId: menuId,
    title: title,
    quantity: quantity,
    price: price,
    subtotal: subtotal,
  );
}

/// Catatan untuk satu item habis: apa yang habis, berapa nilainya, dan
/// bagaimana diselesaikan.
class ItemSwap {
  const ItemSwap({
    required this.menuId,
    required this.title,
    required this.quantity,
    required this.nilaiAsal,
    this.pengganti = const [],
    this.penyelesaian,
    this.selisihDibayar = 0,
  });

  /// Dibentuk dari baris pesanan yang ditandai habis.
  factory ItemSwap.dariBaris(OrderLine line) => ItemSwap(
    menuId: line.menuId,
    title: line.title,
    quantity: line.quantity,
    // Nilai yang sudah dibayar untuk baris ini — dasar seluruh hitungan.
    nilaiAsal: line.subtotal > 0 ? line.subtotal : line.price * line.quantity,
  );

  final int menuId;
  final String title;
  final int quantity;

  /// Harga × qty yang sudah dibayar pembeli untuk item ini.
  final int nilaiAsal;

  final List<SwapPick> pengganti;

  /// Null selama pembeli belum memutuskan.
  final SwapResolution? penyelesaian;

  /// Kekurangan yang sudah dibayar lewat halaman Pembayaran.
  final int selisihDibayar;

  bool get selesai => penyelesaian != null;

  int get totalPengganti => pengganti.fold(0, (a, p) => a + p.subtotal);

  /// Positif = pengganti lebih mahal (pembeli menambah). Negatif = pengganti
  /// belum senilai — belum boleh dikonfirmasi.
  int get selisih => hitungSelisih(nilaiAsal, totalPengganti);

  /// Kalimat ringkas untuk riwayat, mis. "Donat Coklat ×2 → diganti Bolen
  /// Keju ×2".
  String get catatan {
    final asal = '$title ×$quantity';
    return switch (penyelesaian) {
      SwapResolution.diganti =>
        '$asal → diganti ${pengganti.map((p) => '${p.title} ×${p.quantity}').join(', ')}',
      null => '$asal → belum dipilih',
    };
  }

  /// Item ini cocok dengan [line]. Id menu didahulukan; judul hanya cadangan
  /// untuk baris yang datang tanpa id.
  bool cocokDengan(OrderLine line) => menuId > 0
      ? line.menuId == menuId
      : line.title.trim().toLowerCase() == title.trim().toLowerCase();

  ItemSwap diganti(List<SwapPick> picks, {int selisihDibayar = 0}) => ItemSwap(
    menuId: menuId,
    title: title,
    quantity: quantity,
    nilaiAsal: nilaiAsal,
    pengganti: List.unmodifiable(picks),
    penyelesaian: SwapResolution.diganti,
    selisihDibayar: selisihDibayar,
  );

  Map<String, dynamic> toJson() => {
    'menu_id': menuId,
    'title': title,
    'quantity': quantity,
    'nilai_asal': nilaiAsal,
    'pengganti': [for (final p in pengganti) p.toJson()],
    'penyelesaian': penyelesaian?.code,
    'selisih_dibayar': selisihDibayar,
  };

  factory ItemSwap.fromJson(Map<String, dynamic> json) {
    final raw = json['pengganti'];
    return ItemSwap(
      menuId: _int(json['menu_id']),
      title: (json['title'] ?? '').toString(),
      quantity: _int(json['quantity']),
      nilaiAsal: _int(json['nilai_asal']),
      pengganti: raw is List
          ? raw
                .whereType<Map>()
                .map((e) => SwapPick.fromJson(e.cast<String, dynamic>()))
                .toList(growable: false)
          : const [],
      penyelesaian: SwapResolution.fromCode(json['penyelesaian']),
      selisihDibayar: _int(json['selisih_dibayar']),
    );
  }
}

/// Selisih penggantian: positif = pembeli membayar kekurangannya, negatif =
/// pengganti belum senilai item yang dibayar.
int hitungSelisih(int nilaiDibayar, int totalPengganti) =>
    totalPengganti - nilaiDibayar;

/// Keadaan Ganti Item untuk satu pesanan.
class OrderSwap {
  const OrderSwap({
    required this.orderId,
    required this.documentNumber,
    required this.items,
    this.pesananTiruan,
    this.diserahkan = false,
  });

  final int orderId;
  final String documentNumber;
  final List<ItemSwap> items;

  /// Pesanan buatan (bentuk respons `GET /orders/:id`) bila simulasi tidak
  /// memakai pesanan asli. Null = pesanan asli dari server.
  final Map<String, dynamic>? pesananTiruan;

  /// Khusus pesanan tiruan: sudah "diserahkan kasir" → pindah ke Riwayat.
  final bool diserahkan;

  bool get isTiruan => pesananTiruan != null;

  int get belumSelesai => items.where((i) => !i.selesai).length;

  bool get semuaSelesai => belumSelesai == 0;

  /// Item habis berikutnya yang masih perlu dipilih.
  ItemSwap? get berikutnya {
    for (final i in items) {
      if (!i.selesai) return i;
    }
    return null;
  }

  int get totalSelisihDibayar => items.fold(0, (a, i) => a + i.selisihDibayar);

  List<ItemSwap> get selesaiSaja =>
      items.where((i) => i.selesai).toList(growable: false);

  OrderSwap ganti(ItemSwap updated) => OrderSwap(
    orderId: orderId,
    documentNumber: documentNumber,
    items: [
      for (final i in items)
        i.menuId == updated.menuId && i.title == updated.title ? updated : i,
    ],
    pesananTiruan: pesananTiruan,
    diserahkan: diserahkan,
  );

  OrderSwap serahkan() => OrderSwap(
    orderId: orderId,
    documentNumber: documentNumber,
    items: items,
    pesananTiruan: pesananTiruan,
    diserahkan: true,
  );

  /// Tempelkan keadaan ini di atas [order] dari server.
  ///
  /// Aman dipanggil berulang pada pesanan yang sudah ditempeli — hasilnya
  /// sama. Itu penting karena daftar yang sama bisa melewati repository lalu
  /// store sekaligus.
  Order applyTo(Order order) {
    final lines = order.hasLines
        ? [for (final line in order.lines) _applyLine(line)]
        : order.lines;

    var status = order.status;
    var label = order.statusLabel;
    if (!semuaSelesai && status.isPaid) {
      status = OrderStatus.perluTindakan;
      label = 'Perlu tindakan';
    } else if (semuaSelesai && status == OrderStatus.perluTindakan) {
      // Semua item sudah diputuskan → pesanan lanjut disiapkan.
      status = OrderStatus.appPaid;
      label = 'Sedang disiapkan';
    }
    return order.copyWith(status: status, statusLabel: label, lines: lines);
  }

  OrderLine _applyLine(OrderLine line) {
    for (final swap in items) {
      if (!swap.cocokDengan(line)) continue;
      return line.copyWith(
        tidakTersedia: true,
        pengganti: swap.penyelesaian == SwapResolution.diganti
            ? [for (final p in swap.pengganti) p.toLine()]
            : const [],
      );
    }
    return line;
  }

  Map<String, dynamic> toJson() => {
    'order_id': orderId,
    'document_number': documentNumber,
    'items': [for (final i in items) i.toJson()],
    'pesanan_tiruan': pesananTiruan,
    'diserahkan': diserahkan,
  };

  factory OrderSwap.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final tiruan = json['pesanan_tiruan'];
    return OrderSwap(
      orderId: _int(json['order_id']),
      documentNumber: (json['document_number'] ?? '').toString(),
      items: raw is List
          ? raw
                .whereType<Map>()
                .map((e) => ItemSwap.fromJson(e.cast<String, dynamic>()))
                .toList(growable: false)
          : const [],
      pesananTiruan: tiruan is Map ? tiruan.cast<String, dynamic>() : null,
      diserahkan: json['diserahkan'] == true,
    );
  }
}

int _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
