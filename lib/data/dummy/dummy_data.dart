import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../models/promo_banner.dart';
import '../models/saved_address.dart';
import '../models/user_profile.dart';
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

  static const String outletName = 'Panglima Cabang Samarinda';
  static const String outletAddress =
      'Jl. Palang Merah No. 12, Samarinda, Kalimantan Timur';

  /// Daftar outlet untuk pemilihan (halaman Menu).
  static const List<({String name, String address})> outlets = [
    (
      name: 'Panglima Cabang Samarinda',
      address: 'Jl. Palang Merah No. 12, Samarinda, Kalimantan Timur',
    ),
    (
      name: 'Panglima Cabang Balikpapan',
      address: 'Jl. Jenderal Sudirman No. 45, Balikpapan, Kalimantan Timur',
    ),
    (
      name: 'Panglima Cabang Tenggarong',
      address: 'Jl. KH. Ahmad Muksin No. 8, Tenggarong, Kutai Kartanegara',
    ),
    (
      name: 'Panglima Cabang Bontang',
      address: 'Jl. MT. Haryono No. 21, Bontang, Kalimantan Timur',
    ),
  ];

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
  // PRODUK / MENU
  // ---------------------------------------------------------------------------

  static const List<Product> products = [
    Product(
      id: 'P01',
      name: 'Roti Gembung Original',
      category: 'Roti Gembung',
      price: 8000,
      description: 'Roti gembung klasik, empuk dan gurih.',
      emoji: '🥯',
      imageUrl:
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&q=60&auto=format&fit=crop',
    ),
    Product(
      id: 'P02',
      name: 'Roti Gembung Cokelat',
      category: 'Roti Gembung',
      price: 10000,
      description: 'Isian cokelat lumer khas Panglima.',
      emoji: '🍫',
      imageUrl:
          'https://images.unsplash.com/photo-1541167760496-1628856ab772?w=400&q=60&auto=format&fit=crop',
    ),
    Product(
      id: 'P03',
      name: 'Roti Gembung Keju',
      category: 'Roti Gembung',
      price: 11000,
      description: 'Taburan keju melimpah, asin manis pas.',
      emoji: '🧀',
      imageUrl:
          'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400&q=60&auto=format&fit=crop',
    ),
    Product(
      id: 'P04',
      name: 'Roti Srikaya',
      category: 'Roti Gembung',
      price: 15000,
      description: 'Selai srikaya lembut bikin nagih.',
      emoji: '🥮',
      imageUrl:
          'https://images.unsplash.com/photo-1470337458703-46ad1756a187?w=400&q=60&auto=format&fit=crop',
    ),
    Product(
      id: 'P05',
      name: 'Roti Keju Manis',
      category: 'Roti',
      price: 13000,
      description: 'Roti manis dengan topping keju melimpah.',
      emoji: '🧀',
      imageUrl:
          'https://images.unsplash.com/photo-1509785307050-d4066910ec1e?w=400&q=60&auto=format&fit=crop',
    ),
    Product(
      id: 'P06',
      name: 'Roti Coklat Klasik',
      category: 'Roti',
      price: 9000,
      description: 'Roti isi cokelat klasik favorit semua.',
      emoji: '🍫',
      imageUrl:
          'https://images.unsplash.com/photo-1587049633312-d628ae50a8ae?w=400&q=60&auto=format&fit=crop',
    ),
    Product(
      id: 'P07',
      name: 'Sugar Donut',
      category: 'Makanan',
      price: 10000,
      description: 'Donat gula lembut dan manis.',
      emoji: '🍩',
      imageUrl:
          'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=400&q=60&auto=format&fit=crop',
    ),
    Product(
      id: 'P08',
      name: 'Chocolate Donut',
      category: 'Makanan',
      price: 13000,
      description: 'Donat cokelat dengan glaze tebal.',
      emoji: '🍩',
      imageUrl:
          'https://images.unsplash.com/photo-1533910534207-90f31029a78e?w=400&q=60&auto=format&fit=crop',
    ),
    Product(
      id: 'P09',
      name: 'Chocolate Croissant',
      category: 'Makanan',
      price: 19000,
      description: 'Croissant renyah isi cokelat.',
      emoji: '🥐',
      imageUrl:
          'https://images.unsplash.com/photo-1587668178277-295251f900ce?w=400&q=60&auto=format&fit=crop',
    ),
    Product(
      id: 'P10',
      name: 'Salt Bread Sausage',
      category: 'Makanan',
      price: 16000,
      description: 'Roti asin isi sosis, gurih mantap.',
      emoji: '🌭',
      isNew: true,
      imageUrl:
          'https://images.unsplash.com/photo-1509365465985-25d11c17e812?w=400&q=60&auto=format&fit=crop',
    ),
    Product(
      id: 'P11',
      name: 'Coffee Butter Bun',
      category: 'Roti',
      price: 12000,
      description: 'Roti butter aroma kopi, baru!',
      emoji: '🥖',
      isNew: true,
      imageUrl:
          'https://images.unsplash.com/photo-1481391319762-47dff72954d9?w=400&q=60&auto=format&fit=crop',
    ),
    Product(
      id: 'P12',
      name: 'Kopi Panglima',
      category: 'Minuman',
      price: 18000,
      promoPrice: 15000,
      description: 'Kopi susu gula aren, teman roti gembung.',
      emoji: '☕',
      imageUrl:
          'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400&q=60&auto=format&fit=crop',
    ),
    Product(
      id: 'P13',
      name: 'Teh Tarik',
      category: 'Minuman',
      price: 12000,
      description: 'Teh tarik hangat creamy.',
      emoji: '🧋',
      imageUrl:
          'https://images.unsplash.com/photo-1517701604599-bb29b565090c?w=400&q=60&auto=format&fit=crop',
    ),
    Product(
      id: 'P14',
      name: 'Paket Duo Gembung',
      category: 'Paket',
      price: 24000,
      promoPrice: 20000,
      description: '2 roti gembung pilihan + 1 kopi.',
      emoji: '🎁',
      badge: 'Promo Delivery',
      imageUrl:
          'https://images.unsplash.com/photo-1568254183919-78a4f43a2877?w=400&q=60&auto=format&fit=crop',
    ),
    Product(
      id: 'P15',
      name: 'Paket Hemat Berdua',
      category: 'Paket',
      price: 35000,
      promoPrice: 29900,
      description: '4 roti gembung + 2 minuman.',
      emoji: '🧺',
      badge: 'Promo Delivery',
      imageUrl:
          'https://images.unsplash.com/photo-1517686469429-8bdb88b9f907?w=400&q=60&auto=format&fit=crop',
    ),
  ];

  static Product _p(String id) => products.firstWhere((e) => e.id == id);

  /// Daftar kategori unik dari [products].
  static List<String> get categories =>
      products.map((p) => p.category).toSet().toList();

  // --- Section Beranda ---

  /// "Spesial Hari Ini" — produk yang sedang promo.
  static List<Product> get spesialHariIni =>
      products.where((p) => p.isPromo).toList();

  /// "Baru!" — produk baru.
  static List<Product> get produkBaru =>
      products.where((p) => p.isNew).toList();

  /// "Makanan" — kategori makanan.
  static List<Product> get makanan =>
      products.where((p) => p.category == 'Makanan').toList();

  /// "Order Lagi" — produk yang sering dibeli, lengkap dengan label outlet
  /// transaksi sebelumnya (dummy).
  static List<({Product product, String outletLabel})> get orderLagi => [
    (product: _p('P12'), outletLabel: 'Panglima Cabang Samarinda'),
    (product: _p('P01'), outletLabel: 'Panglima Cabang Samarinda'),
    (product: _p('P05'), outletLabel: 'Panglima Cabang Balikpapan'),
    (product: _p('P07'), outletLabel: 'Panglima Cabang Samarinda'),
  ];

  /// Section untuk halaman Menu: judul kategori + produknya, terurut.
  /// "Promo & Combo" dan "Baru!" adalah section kurasi (bisa memuat produk
  /// yang juga muncul di kategori dasarnya) — mengikuti pola Kopi Kenangan.
  static List<({String title, List<Product> items})> get menuSections {
    List<Product> byCategory(String c) =>
        products.where((p) => p.category == c).toList();
    final sections = <({String title, List<Product> items})>[
      (
        title: 'Promo & Combo',
        items: products.where((p) => p.isPromo).toList(),
      ),
      (title: 'Baru!', items: products.where((p) => p.isNew).toList()),
      (title: 'Roti Gembung', items: byCategory('Roti Gembung')),
      (title: 'Roti', items: byCategory('Roti')),
      (title: 'Makanan', items: byCategory('Makanan')),
      (title: 'Minuman', items: byCategory('Minuman')),
    ];
    return sections.where((s) => s.items.isNotEmpty).toList();
  }

  // ---------------------------------------------------------------------------
  // BANNER PROMO (carousel Beranda)
  // ---------------------------------------------------------------------------

  static const List<PromoBanner> banners = [
    PromoBanner(
      label: 'SETIAP HARI',
      title: 'Diskon Spesial',
      highlight: 'hingga 30%',
      subtitle: 'untuk semua Roti Gembung favoritmu',
      imageUrl:
          'https://images.unsplash.com/photo-1608198093002-ad4e005484ec?w=600&q=60&auto=format&fit=crop',
      badges: ['Disc 10% Member Gold'],
    ),
    PromoBanner(
      label: 'PROMO MINUMAN',
      title: 'Gratis 1 Kopi',
      highlight: 'Beli 1 Gratis 1',
      subtitle: 'berlaku tiap hari, semua outlet Panglima',
      imageUrl:
          'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&q=60&auto=format&fit=crop',
      badges: ['Tanpa Minimal Order'],
    ),
    PromoBanner(
      label: 'PAKET HEMAT',
      title: 'Paket Berdua',
      highlight: 'Rp 29.900',
      subtitle: '4 roti gembung + 2 minuman pilihan',
      imageUrl:
          'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=600&q=60&auto=format&fit=crop',
      badges: ['Hemat 15%'],
    ),
  ];

  // ---------------------------------------------------------------------------
  // PESANAN (aktif + selesai untuk history)
  // ---------------------------------------------------------------------------

  static final List<Order> orders = [
    Order(
      id: 'ORD-1042',
      customer: 'Budi Santoso',
      status: OrderStatus.pending,
      createdAt: DateTime(2026, 7, 6, 8, 15),
      items: [
        OrderItem(product: _p('P01'), qty: 3),
        OrderItem(product: _p('P12'), qty: 2),
      ],
    ),
    Order(
      id: 'ORD-1041',
      customer: 'Siti Aminah',
      status: OrderStatus.diproses,
      createdAt: DateTime(2026, 7, 6, 7, 50),
      items: [
        OrderItem(product: _p('P02'), qty: 2),
        OrderItem(product: _p('P03'), qty: 1),
      ],
    ),
    Order(
      id: 'ORD-1040',
      customer: 'Ahmad Fauzi',
      status: OrderStatus.diproses,
      createdAt: DateTime(2026, 7, 6, 7, 30),
      items: [OrderItem(product: _p('P15'), qty: 1)],
    ),
    Order(
      id: 'ORD-1039',
      customer: 'Dewi Lestari',
      status: OrderStatus.selesai,
      createdAt: DateTime(2026, 7, 5, 16, 20),
      items: [
        OrderItem(product: _p('P04'), qty: 4),
        OrderItem(product: _p('P13'), qty: 2),
      ],
    ),
    Order(
      id: 'ORD-1038',
      customer: 'Rizky Pratama',
      status: OrderStatus.selesai,
      createdAt: DateTime(2026, 7, 5, 14, 5),
      items: [OrderItem(product: _p('P06'), qty: 3)],
    ),
    Order(
      id: 'ORD-1037',
      customer: 'Maya Sari',
      status: OrderStatus.dibatalkan,
      createdAt: DateTime(2026, 7, 5, 11, 40),
      items: [OrderItem(product: _p('P01'), qty: 2)],
    ),
  ];

  /// Pesanan yang masih berjalan (tab Pesanan).
  static List<Order> get activeOrders =>
      orders.where((o) => o.status.isActive).toList();

  /// Pesanan yang sudah selesai / dibatalkan (tab History).
  static List<Order> get historyOrders =>
      orders.where((o) => o.status.isDone).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ---------------------------------------------------------------------------
  // PROFIL
  // ---------------------------------------------------------------------------

  static const UserProfile profile = UserProfile(
    name: 'Syafar',
    role: 'user',
    phone: '0812-3456-7890',
    email: 'outlet@panglima.id',
    avatarEmoji: '🍞',
  );

  // ---------------------------------------------------------------------------
  // RINGKASAN
  // ---------------------------------------------------------------------------

  /// Total penjualan hari ini (dari pesanan selesai).
  static int get penjualanHariIni => orders
      .where((o) => o.status == OrderStatus.selesai)
      .fold(0, (sum, o) => sum + o.total);

  /// Jumlah pesanan aktif.
  static int get jumlahPesananAktif => activeOrders.length;
}
