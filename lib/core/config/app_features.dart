import 'package:flutter/foundation.dart';

/// Modul **Ganti Item Tidak Tersedia** — belum selesai, jadi hanya aktif di
/// build debug.
///
/// Sengaja `const`: pada build profile/rilis nilainya `false` sejak kompilasi,
/// sehingga seluruh kode modul di belakang gate ini ikut dibuang
/// (tree-shaking) — halaman, simulasi, maupun status `perlu_tindakan`.
///
/// Untuk build uji internal, nyalakan manual dengan
/// `--dart-define=FITUR_GANTI_ITEM=true`. Jangan dipasang di konfigurasi
/// build mana pun sebelum modul dinyatakan siap rilis.
///
/// Semua titik gate ditandai `TODO(ganti-item)` — cari tanda itu untuk
/// membukanya sekaligus.
const bool kFiturGantiItem = bool.fromEnvironment(
  'FITUR_GANTI_ITEM',
  defaultValue: kDebugMode,
);

/// Saklar fitur yang belum rilis.
///
/// Semua fitur yang masih memakai data karangan atau belum punya endpoint
/// dikumpulkan di sini, supaya menyalakannya kembali cukup mengubah satu
/// `false` menjadi `true` — bukan memburu potongan kode yang tersebar di
/// belasan berkas.
///
/// **Dua perlakuan yang dipakai:**
/// - *Dikunci* — tetap terlihat, tidak bisa ditekan, diberi label
///   "Segera hadir". Untuk fitur yang memang direncanakan, supaya pembeli tahu
///   aplikasinya akan berkembang.
/// - *Disembunyikan* — hilang sama sekali. Untuk menu yang belum jelas
///   kebutuhannya; memasangnya sebagai "segera hadir" hanya menjanjikan
///   sesuatu yang belum tentu dibuat.
///
/// Aturan yang dipegang: **jangan pernah menampilkan angka karangan sebagai
/// angka sungguhan.** Poin, tier, dan voucher lebih baik berbunyi "Segera
/// hadir" ketimbang menyebut nilai yang tidak dimiliki pembeli.
class AppFeatures {
  const AppFeatures._();

  /// Teks yang dipakai seragam di seluruh aplikasi untuk fitur terkunci.
  static const String segeraHadir = 'Segera hadir';

  // --- Dikunci (terlihat, tidak aktif) --------------------------------------

  /// Pengantaran ke alamat. Butuh endpoint ongkir & checkout yang menerima
  /// alamat; tanpa itu pesanan delivery tidak bisa dikirim ke server sama
  /// sekali.
  static const bool delivery = false;

  /// Alamat pengiriman tersimpan. Menyusul [delivery] — sekarang hanya
  /// tersimpan di HP dan hilang bila aplikasi dipasang ulang.
  static const bool alamatTersimpan = false;

  /// Poin & tingkat keanggotaan (Beranda, Profile, Checkout).
  static const bool loyalty = false;

  /// Voucher: daftar, klaim, pakai, tukar kode.
  static const bool voucher = false;

  /// Halaman Panglima VIP. Tabnya tetap ada di navbar — isinya yang diganti
  /// halaman "segera hadir", supaya susunan navbar tidak berubah dua kali.
  static const bool vip = false;

  // --- Konten & tautan (dikunci sampai alamatnya ada) -----------------------
  //
  // Semuanya TIDAK butuh endpoint — hanya URL halaman web atau nomor tujuan.
  // Dikunci, bukan disembunyikan, karena memang direncanakan dan pembeli
  // wajar mencarinya di menu. Nyalakan satu per satu begitu alamatnya siap.

  /// Halaman bantuan / FAQ.
  static const bool bantuan = false;

  /// Kebijakan privasi. **Wajib ada sebelum terbit di Play Store**, beserta
  /// URL-nya di Play Console.
  static const bool kebijakanPrivasi = false;

  /// Ketentuan layanan.
  static const bool ketentuanLayanan = false;

  /// Formulir/kanal laporan masalah.
  static const bool laporMasalah = false;

  /// Tautan ke WhatsApp layanan pelanggan — cukup nomor tujuan.
  static const bool layananWhatsapp = false;

  /// Halaman "Tentang Aplikasi" (versi, lisensi, kontak).
  static const bool tentangAplikasi = false;

  // --- Disembunyikan (hilang dari layar) ------------------------------------

  /// Absen harian. Belum menyimpan apa pun.
  static const bool dailyCheckIn = false;

  /// Kotak masuk / riwayat notifikasi dalam aplikasi.
  static const bool kotakMasuk = false;

  /// Pemindai merchandise. Kebutuhan bisnisnya belum ditetapkan.
  static const bool scanMerchandise = false;

  /// Ganti bahasa aplikasi.
  static const bool ubahBahasa = false;

  /// Masuk dengan sidik jari / wajah. Saklarnya dulu bisa digeser padahal
  /// tidak mengunci apa pun — persis jenis kebohongan yang dihindari berkas
  /// ini.
  static const bool biometrik = false;

  /// Metode pembayaran tersimpan.
  static const bool metodePembayaranTersimpan = false;

  /// Pemesanan jumlah besar.
  static const bool pesananJumlahBesar = false;
}
