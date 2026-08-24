import 'package:flutter/material.dart';

/// Status sebuah tier VIP relatif terhadap posisi member saat ini.
enum TierStatus {
  /// Tier yang sudah dilewati member (semua keuntungan sudah termasuk).
  surpassed,

  /// Tier member saat ini.
  current,

  /// Tier di atas (belum terbuka) — keuntungan masih terkunci.
  locked,
}

/// Satu keuntungan (benefit) pada sebuah tier VIP.
class VipBenefit {
  const VipBenefit({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

/// Satu voucher yang bisa dipakai di App.
class VipVoucher {
  const VipVoucher({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.validUntil,
    this.tag = 'Pakai di App',
  });

  /// Kategori untuk filter: `Diskon`, `Cashback`, atau `Delivery`.
  final String category;
  final String title;
  final String subtitle;
  final String validUntil;
  final String tag;
}

/// Paket langganan voucher (dibeli sekaligus, hemat).
class VipVoucherPack {
  const VipVoucherPack({
    required this.title,
    required this.description,
    required this.originalPrice,
    required this.price,
    required this.savePercent,
    required this.voucherCount,
  });

  final String title;
  final String description;
  final int originalPrice;
  final int price;
  final int savePercent;
  final int voucherCount;
}

/// Satu tingkat keanggotaan VIP (mis. Silver / Gold / Black), lengkap dengan
/// identitas visual kartu dan konten Voucher / Voucher Pack / Benefit-nya.
class VipTier {
  const VipTier({
    required this.name,
    required this.badge,
    required this.status,
    required this.points,
    required this.goal,
    required this.progress,
    required this.note,
    required this.gradient,
    required this.onCard,
    required this.barColor,
    required this.background,
    required this.emblem,
    required this.vouchers,
    required this.packs,
    required this.benefits,
  });

  final String name;

  /// Label pada chip kecil di sebelah nama (mis. `10%`, `Locked`, `Sebelumnya`).
  final String badge;
  final TierStatus status;

  /// Poin/belanja member saat ini (pembilang).
  final int points;

  /// Target menuju tier berikutnya (penyebut).
  final int goal;

  /// Kemajuan bar, 0..1.
  final double progress;

  /// Keterangan di bawah progress bar.
  final String note;

  /// Gradien latar kartu tier.
  final List<Color> gradient;

  /// Warna teks di atas kartu (kontras terhadap [gradient]).
  final Color onCard;

  /// Warna isi progress bar pada kartu.
  final Color barColor;

  /// Tint latar halaman saat tier ini aktif.
  final Color background;

  /// Ikon lambang di lingkaran kanan kartu.
  final IconData emblem;

  final List<VipVoucher> vouchers;
  final List<VipVoucherPack> packs;
  final List<VipBenefit> benefits;

  bool get isLocked => status == TierStatus.locked;
}
