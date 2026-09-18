import 'package:flutter/material.dart';

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

}
