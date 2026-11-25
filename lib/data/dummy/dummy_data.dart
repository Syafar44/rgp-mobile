import 'package:flutter/material.dart';

import '../../core/config/app_images.dart';
import '../../core/utils/wita.dart';
import '../models/product.dart';
import '../models/promo_banner.dart';
import '../models/saved_address.dart';
import '../models/vip.dart';

/// Tempat sementara menyimpan data dummy aplikasi.
///
/// Semua data di sini hanya untuk pengembangan UI sebelum API tersedia.
/// Saat backend siap, ganti pemanggilan [DummyData] dengan repository yang
/// memakai Dio (`lib/core/network/dio_client.dart`).
class DummyData {
  DummyData._();

  // ---------------------------------------------------------------------------
  // LOYALTY & LOKASI (header Beranda)
  // ---------------------------------------------------------------------------

  static const String loyaltyTier = 'Gold';
  static const int loyaltyPercent = 10;
  static const int poin = 600;

  // Outlet kini dari API (`OutletRepository.nearby`), bukan dummy lagi.

  /// Alamat delivery awal (seed untuk AddressStore).
  static final List<SavedAddress> seedAddresses = [
    const SavedAddress(
      id: 'A1',
      label: 'Gerai panglima',
      fullAddress:
          'Jl. Ir. H. Juanda No.88, Sidodadi, Kec. Samarinda Ulu, '
          'Kota Samarinda, Kalimantan Timur 75124',
      note: 'samping dealer Daihatsu, gerai panglima / roti gembung panglima',
      recipient: 'Syafar',
      phone: '082250851457',
      isPrimary: true,
    ),
  ];

  // ---------------------------------------------------------------------------
  // VIP / KEANGGOTAAN (tab VIP)
  // ---------------------------------------------------------------------------

  static const String vipMemberName = 'Syafar';

  /// Tingkatan keanggotaan Panglima VIP. Urutan carousel: Silver → Gold → Black.
  /// Member saat ini ada di tier Gold (index 1).
  static const List<VipTier> vipTiers = [
    // ── SILVER (sudah dilewati) ──────────────────────────────────────────
    VipTier(
      name: 'SILVER',
      badge: 'Sebelumnya',
      status: TierStatus.surpassed,
      points: 1023450,
      goal: 699999,
      progress: 1,
      note: 'Kamu sudah melampaui tier ini. Semua keuntungan sudah termasuk.',
      gradient: [Color(0xFFF1F3F5), Color(0xFFCED4DA)],
      onCard: Color(0xFF2D1B12),
      barColor: Color(0xFF7E1416),
      background: Color(0xFFF3F5F7),
      emblem: Icons.workspace_premium,
      vouchers: [
        VipVoucher(
          category: 'Delivery',
          title: 'Gratis Ongkir s/d Rp10.000',
          subtitle: 'Min. pembelian Rp30.000, berlaku semua outlet.',
          validUntil: '31 Jul 2026',
        ),
        VipVoucher(
          category: 'Diskon',
          title: 'Diskon 15% Roti Gembung',
          subtitle: 'Khusus roti gembung original & cokelat.',
          validUntil: '25 Jul 2026',
        ),
      ],
      packs: [
        VipVoucherPack(
          title: 'Paket Hemat Silver Rp5.000',
          description:
              '5x Voucher Diskon 10%, 2x Voucher Gratis Ongkir, berlaku 30 hari.',
          originalPrice: 60000,
          price: 5000,
          savePercent: 92,
          voucherCount: 7,
        ),
      ],
      benefits: [
        VipBenefit(
          icon: Icons.savings_outlined,
          title: 'Cashback 5%',
          description: 'Dapatkan Panglima Points 5% tiap transaksimu.',
        ),
        VipBenefit(
          icon: Icons.local_shipping_outlined,
          title: 'Gratis Ongkir Mingguan',
          description: 'Satu voucher gratis ongkir tiap minggu.',
        ),
        VipBenefit(
          icon: Icons.cake_outlined,
          title: 'Birthday Treats',
          description: 'E-voucher spesial di bulan ulang tahunmu.',
        ),
      ],
    ),
    // ── GOLD (tier saat ini) ─────────────────────────────────────────────
    VipTier(
      name: 'GOLD',
      badge: '10%',
      status: TierStatus.current,
      points: 1023450,
      goal: 9999999,
      progress: 0.1,
      note: 'Belanja Rp8.976.549 lagi untuk naik ke Level Black.',
      gradient: [Color(0xFFFCE9A8), Color(0xFFE3B23C)],
      onCard: Color(0xFF4A0A0C),
      barColor: Color(0xFF7E1416),
      background: Color(0xFFFBF3DD),
      emblem: Icons.bakery_dining,
      vouchers: [
        VipVoucher(
          category: 'Diskon',
          title: 'Diskon 35% s/d Rp35.000 — Selalu Lebih Murah',
          subtitle: 'Nikmati diskon s/d 35RB untuk min. pembelian Rp50.000.',
          validUntil: '22 Jul 2026',
        ),
        VipVoucher(
          category: 'Cashback',
          title: 'Cashback 10% Panglima Points',
          subtitle: 'Berlaku semua menu, tanpa minimal pembelian.',
          validUntil: '28 Jul 2026',
        ),
        VipVoucher(
          category: 'Delivery',
          title: 'Gratis Ongkir GoSend & GrabExpress',
          subtitle: 'Khusus member Gold, min. pembelian Rp25.000.',
          validUntil: '30 Jul 2026',
        ),
      ],
      packs: [
        VipVoucherPack(
          title: 'Langganan Voucher Rp9.000',
          description:
              '1x Voucher B1G1, 2x Voucher B2G1, 30x Voucher Diskon 10%, '
              '30x Voucher Diskon Ongkir.',
          originalPrice: 630000,
          price: 9000,
          savePercent: 98,
          voucherCount: 65,
        ),
        VipVoucherPack(
          title: 'Langganan Voucher Rp24.000',
          description:
              '1x Voucher Gratis 1 Minuman, 1x Voucher B1G1, 2x Voucher B2G1, '
              '30x Voucher Diskon 15%.',
          originalPrice: 680000,
          price: 24000,
          savePercent: 96,
          voucherCount: 66,
        ),
      ],
      benefits: [
        VipBenefit(
          icon: Icons.savings_outlined,
          title: 'Cashback 10%',
          description: 'Dapatkan Panglima Points 10% tiap transaksimu.',
        ),
        VipBenefit(
          icon: Icons.card_giftcard_outlined,
          title: 'Membership Voucher',
          description: 'Voucher diskon produk / ongkir tiap bulannya.',
        ),
        VipBenefit(
          icon: Icons.cake_outlined,
          title: 'Birthday Treats',
          description: 'E-voucher birthday spesial dari Panglima.',
        ),
        VipBenefit(
          icon: Icons.support_agent_outlined,
          title: 'Priority Support',
          description: 'Bantuan lebih cepat via WhatsApp resmi Panglima.',
        ),
      ],
    ),
    // ── BLACK (terkunci — target berikutnya) ─────────────────────────────
    VipTier(
      name: 'BLACK',
      badge: 'Locked',
      status: TierStatus.locked,
      points: 1023450,
      goal: 9999999,
      progress: 0.1,
      note: 'Belanja Rp8.976.549 lagi untuk naik ke Level Black.',
      gradient: [Color(0xFF3A2A2B), Color(0xFF1A0405)],
      onCard: Color(0xFFFFFFFF),
      barColor: Color(0xFFFFC107),
      background: Color(0xFFECEDEF),
      emblem: Icons.lock_outline,
      vouchers: [
        VipVoucher(
          category: 'Diskon',
          title: 'Diskon 50% Eksklusif Black',
          subtitle: 'Terbuka setelah kamu mencapai Level Black.',
          validUntil: 'Menunggu terbuka',
        ),
        VipVoucher(
          category: 'Delivery',
          title: 'Gratis Ongkir Tanpa Batas',
          subtitle: 'Ongkir unlimited khusus member Black.',
          validUntil: 'Menunggu terbuka',
        ),
      ],
      packs: [
        VipVoucherPack(
          title: 'Langganan Voucher Black Rp49.000',
          description:
              '5x Voucher B1G1, 60x Voucher Diskon 15%, 10x Gratis Ongkir, '
              'akses menu eksklusif.',
          originalPrice: 1200000,
          price: 49000,
          savePercent: 96,
          voucherCount: 120,
        ),
      ],
      benefits: [
        VipBenefit(
          icon: Icons.savings_outlined,
          title: 'Cashback 15%',
          description: 'Dapatkan Panglima Points 15% tiap transaksimu.',
        ),
        VipBenefit(
          icon: Icons.restaurant_menu_outlined,
          title: 'Exclusive Menu Access',
          description: 'Coba menu baru/populer lebih dulu.',
        ),
        VipBenefit(
          icon: Icons.star_outline,
          title: 'Special Treats',
          description: 'Penawaran spesial khusus Black Members.',
        ),
        VipBenefit(
          icon: Icons.local_offer_outlined,
          title: 'Exclusive Promotion',
          description: 'Promo eksklusif tiap bulan untuk Black Members.',
        ),
        VipBenefit(
          icon: Icons.all_inclusive,
          title: 'Free Delivery Unlimited',
          description: 'Bebas ongkir tanpa batas, semua outlet.',
        ),
      ],
    ),
  ];

  /// Index tier member saat ini (Gold) — carousel VIP mulai di sini.
  static const int vipCurrentTierIndex = 1;

  // ---------------------------------------------------------------------------
  // BANNER PROMO (carousel Beranda)
  // ---------------------------------------------------------------------------

  /// Sementara memakai gambar dari dalam aplikasi sampai API banner siap.
  /// [PromoBanner.label] tidak ditampilkan — hanya dibaca pembaca layar, jadi
  /// isinya menirukan teks yang tercetak di dalam desain banner.
  static const List<PromoBanner> banners = [
    PromoBanner(
      image: AppImages.banner1,
      label: 'Pia Panglima — teman ngemil paling setia',
    ),
    PromoBanner(
      image: AppImages.banner2,
      label: 'Coklatnya auto bikin senyum — fresh from the oven',
    ),
    PromoBanner(
      image: AppImages.banner3,
      label: 'Roti Subuh, hangatnya menemani mengawali hari — coming soon',
    ),
  ];

  // ---------------------------------------------------------------------------
  // GANTI ITEM TIDAK TERSEDIA (simulasi, khusus build debug)
  // ---------------------------------------------------------------------------
  //
  // Hanya dipanggil `ItemSwapRepository`, yang menolak bekerja bila
  // `kFiturGantiItem` mati — jadi data ini tidak terpakai di build rilis.
  // TODO(ganti-item): hapus gate saat modul dirilis

  /// Katalog cadangan bila menu outlet tidak bisa dimuat (tanpa jaringan,
  /// `.env` kosong, atau di test).
  ///
  /// Harganya dipilih supaya ketiga skenario selisih untuk item habis
  /// bawaan — **Donat Coklat ×2 = Rp16.000** — bisa dicoba langsung:
  /// - **sama**: Bolen Keju ×2 (Rp16.000)
  /// - **kurang**: Bakpia Coklat ×2 (Rp10.000) → belum bisa dikonfirmasi,
  ///   perlu tambah Rp6.000 lagi (belum ada refund)
  /// - **lebih**: Pizza Mini Sosis ×1 (Rp18.000) → bayar selisih Rp2.000
  static const List<Product> katalogCadangan = [
    Product(
      id: '9101',
      name: 'Roti Gembung Original',
      category: 'Roti Gembung',
      price: 10000,
      description: '',
    ),
    Product(
      id: '9102',
      name: 'Roti Gembung Coklat',
      category: 'Roti Gembung',
      price: 12000,
      description: '',
    ),
    Product(
      id: '9103',
      name: 'Roti Gembung Keju',
      category: 'Roti Gembung',
      price: 12000,
      description: '',
    ),
    Product(
      id: '9201',
      name: 'Donat Coklat',
      category: 'Donat',
      price: 8000,
      description: '',
    ),
    Product(
      id: '9202',
      name: 'Donat Gula Halus',
      category: 'Donat',
      price: 6000,
      description: '',
    ),
    Product(
      id: '9203',
      name: 'Donat Keju',
      category: 'Donat',
      price: 8000,
      description: '',
    ),
    Product(
      id: '9301',
      name: 'Pizza Mini Sosis',
      category: 'Pizza',
      price: 18000,
      description: '',
    ),
    Product(
      id: '9302',
      name: 'Pizza Mini Keju',
      category: 'Pizza',
      price: 16000,
      description: '',
    ),
    Product(
      id: '9401',
      name: 'Bakpia Kacang Hijau',
      category: 'Bakpia Basah',
      price: 5000,
      description: '',
    ),
    Product(
      id: '9402',
      name: 'Bakpia Coklat',
      category: 'Bakpia Kering',
      price: 5000,
      description: '',
    ),
    Product(
      id: '9501',
      name: 'Bolen Keju',
      category: 'Bolen',
      price: 8000,
      description: '',
    ),
    Product(
      id: '9502',
      name: 'Bolen Pisang',
      category: 'Bolen',
      price: 9000,
      description: '',
    ),
  ];

  /// Stok tiap produk [katalogCadangan]. Donat Gula Halus sengaja habis
  /// supaya daftar pengganti tidak terlihat seolah semua selalu ada.
  static const Map<String, int> _stokKatalogCadangan = {
    '9101': 12,
    '9102': 6,
    '9103': 4,
    '9201': 0,
    '9202': 0,
    '9203': 7,
    '9301': 3,
    '9302': 5,
    '9401': 10,
    '9402': 8,
    '9501': 9,
    '9502': 6,
  };

  /// Stok tiruan sebuah produk di sebuah outlet.
  ///
  /// Produk katalog cadangan memakai tabel tetap. Menu asli outlet memakai
  /// angka 0–12 yang diturunkan dari id outlet & id produk — tetap sama
  /// setiap dibuka, berbeda antar-outlet, dan sekitar satu dari tujuh produk
  /// habis. Hash dihitung sendiri (bukan `String.hashCode`) supaya hasilnya
  /// tidak bergantung pada versi Dart.
  static int stokTiruan(int outletId, Product product) {
    final tetap = _stokKatalogCadangan[product.id];
    if (tetap != null) return tetap;
    var h = outletId * 31 + 7;
    for (final c in product.id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final n = h % 14;
    return n < 2 ? 0 : n - 1;
  }

  /// Isi pesanan tiruan bila menu outlet tidak tersedia: 3 item, yang
  /// pertama (Donat Coklat ×2) menjadi item habis bawaan.
  static const List<({Product product, int qty})> isiPesananTiruan = [
    (
      product: Product(
        id: '9201',
        name: 'Donat Coklat',
        category: 'Donat',
        price: 8000,
        description: '',
      ),
      qty: 2,
    ),
    (
      product: Product(
        id: '9102',
        name: 'Roti Gembung Coklat',
        category: 'Roti Gembung',
        price: 12000,
        description: '',
      ),
      qty: 1,
    ),
    (
      product: Product(
        id: '9401',
        name: 'Bakpia Kacang Hijau',
        category: 'Bakpia Basah',
        price: 5000,
        description: '',
      ),
      qty: 2,
    ),
  ];

  /// Pesanan berjalan yang sudah dibayar, dalam bentuk respons
  /// `GET /pos/app/v1/orders/:id` — supaya dibaca oleh parser yang sama
  /// dengan pesanan asli.
  static Map<String, dynamic> pesananTiruan({
    required int id,
    required int outletId,
    required String outletName,
    required List<({Product product, int qty})> isi,
  }) {
    final dibuat = nowWita();
    final subtotal = isi.fold<int>(
      0,
      (a, e) => a + e.product.effectivePrice * e.qty,
    );
    // Meniru biaya QRIS di server: 0,9% + PPN 11% atas biaya itu.
    final biaya = (subtotal * 0.009 * 1.11).round();
    return {
      'id': id,
      'document_number': 'SIM$id',
      'order_id': 'SIM$id',
      'outlet_id': outletId,
      'outlet_name': outletName,
      'status': 'app_paid',
      'status_label': 'Sedang disiapkan',
      'total_amount': subtotal,
      'subtotal_amount': subtotal,
      'item_count': isi.fold<int>(0, (a, e) => a + e.qty),
      'amount_fee': biaya,
      'payment_method': 'qris',
      'created_at': rfc3339Wita(dibuat),
      'pickup_at': rfc3339Wita(dibuat.add(const Duration(hours: 1))),
      'keterangan': 'Pesanan simulasi (debug)',
      'charges': {
        'subtotal': subtotal,
        'paid_by_customer': subtotal + biaya,
        'items': [
          {
            'label': 'Biaya QRIS',
            'amount': biaya,
            'charge_type': 'PAYMENT_FEE',
            'bearer': 'CUSTOMER',
          },
        ],
      },
      'lines': [
        for (final e in isi)
          {
            'menu_id': int.tryParse(e.product.id) ?? 0,
            'title': e.product.name,
            'quantity': e.qty,
            'price': e.product.effectivePrice,
            'subtotal': e.product.effectivePrice * e.qty,
          },
      ],
    };
  }
}
