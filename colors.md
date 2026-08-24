# 🎨 Panduan Warna — Aplikasi Roti Gembung Panglima

> **Untuk siapa dokumen ini?**
> Junior programmer, desainer, dan AI assistant yang membantu membangun UI aplikasi.
> Bahasanya sengaja dibuat sederhana. Ikuti aturannya, jangan berimprovisasi warna sendiri.

---

## 1. Ringkasan Cepat (Kalau Malas Baca Semua)

| Peran | Warna | Hex | Dipakai untuk |
|---|---|---|---|
| **Primary** | Merah Maroon | `#7E1416` | AppBar, tombol utama, ikon aktif, harga |
| **Secondary** | Kuning Cerah | `#F8E600` | Highlight, badge promo, aksen kecil |
| **Accent** | Kuning Emas | `#FFC107` | Rating bintang, ikon dekoratif |
| **Background** | Putih | `#FFFFFF` | Latar utama semua halaman |
| **Surface** | Putih Gading | `#FDFBF2` | Kartu produk, panel, bottom sheet |
| **Teks utama** | Coklat Gelap | `#2D1B12` | Semua teks isi |

**3 aturan emas:**
1. Latar aplikasi = putih. Maroon dan kuning hanya AKSEN, bukan latar besar.
2. Teks di atas maroon → **selalu putih**. Teks di atas kuning → **selalu maroon/gelap, JANGAN putih**.
3. Satu layar maksimal punya SATU tombol maroon besar (tombol paling penting).

---

## 2. Asal Warna: Logo Kami

Warna diambil langsung dari logo Roti Gembung Panglima:

- **Merah Maroon `#7E1416`** → warna bingkai dan bagian atas logo. Kesan: hangat, klasik, mengenyangkan (warna kerak roti dan bata oven).
- **Kuning Cerah `#F8E600`** → warna latar bawah logo. Kesan: ceria, lapar, energik.
- **Kuning Emas `#FFC107`** → warna gelombang pada ilustrasi roti. Kesan: mentega, roti matang.
- **Putih `#FFFFFF`** → garis pemisah dan lingkaran logo. Kesan: bersih, higienis.

Kombinasi merah + kuning adalah kombinasi klasik industri makanan (McDonald's, KFC, Indomie) karena warna hangat terbukti membangkitkan selera makan. Kita ikuti pola yang sama, tapi dengan porsi yang lebih "kalem" supaya mata pengguna tidak cepat lelah.

---

## 3. Palet Lengkap + Kode Hex

### 3.1 Merah Maroon (Primary)

| Nama Token | Hex | Kapan dipakai |
|---|---|---|
| `maroon-900` | `#4A0A0C` | Teks di atas kuning, status bar (versi paling gelap) |
| `maroon-700` **(UTAMA)** | `#7E1416` | AppBar, tombol utama, tab aktif, link penting |
| `maroon-500` | `#A32226` | Tombol saat ditekan (pressed), hover |
| `maroon-100` | `#F6E3E3` | Latar chip/badge merah muda lembut |
| `maroon-50` | `#FBF1F1` | Latar seksi yang perlu sedikit "beda" |

### 3.2 Kuning (Secondary)

| Nama Token | Hex | Kapan dipakai |
|---|---|---|
| `yellow-500` **(UTAMA)** | `#F8E600` | Badge "PROMO", highlight teks, garis aksen |
| `yellow-600` | `#E5C400` | Versi kuning yang sedikit lebih gelap, untuk border |
| `gold-500` | `#FFC107` | Bintang rating, ikon hadiah/poin, ilustrasi |
| `yellow-100` | `#FDF9D6` | Latar banner info/promo yang lembut |
| `yellow-50` | `#FEFCEA` | Latar seksi promosi |

### 3.3 Netral (Ini yang Paling Sering Dipakai!)

| Nama Token | Hex | Kapan dipakai |
|---|---|---|
| `white` | `#FFFFFF` | Latar utama (background) aplikasi |
| `cream-surface` | `#FDFBF2` | Kartu, bottom sheet, panel (putih dengan sentuhan hangat) |
| `grey-100` | `#F2EFEA` | Garis pemisah (divider), latar input field |
| `grey-400` | `#9B948C` | Teks placeholder, ikon nonaktif |
| `grey-600` | `#6B6259` | Teks sekunder (deskripsi, keterangan) |
| `text-dark` | `#2D1B12` | Teks utama. **Bukan hitam murni** — coklat gelap supaya lebih hangat dan nyaman di mata |

> 💡 **Kenapa bukan hitam `#000000`?** Hitam murni di layar putih terasa "keras" dan bikin mata cepat lelah. Coklat gelap `#2D1B12` tetap sangat terbaca tapi lebih lembut, dan cocok dengan tema roti/bakery.

### 3.4 Warna Status (Semantic Colors)

Untuk pesan sukses/gagal/peringatan. Jangan pakai maroon untuk error — nanti tertukar dengan warna brand.

| Nama Token | Hex | Dipakai untuk |
|---|---|---|
| `success` | `#2E7D32` | Pesanan berhasil, pembayaran sukses |
| `success-bg` | `#E8F3E9` | Latar snackbar/banner sukses |
| `error` | `#C62828` | Gagal, validasi form salah (lebih terang dari maroon supaya beda) |
| `error-bg` | `#FBEAEA` | Latar pesan error |
| `warning` | `#B26A00` | Stok menipis, koneksi lambat |
| `warning-bg` | `#FFF4E0` | Latar pesan peringatan |
| `info` | `#1565C0` | Informasi netral |
| `info-bg` | `#E7F0FA` | Latar pesan info |

---

## 4. Aturan Komposisi: 60 / 30 / 10

Supaya aplikasi nyaman dilihat lama-lama, ikuti perbandingan ini di setiap layar:

```
60%  →  Putih & Putih Gading   (latar, kartu, ruang kosong)
30%  →  Netral gelap & abu     (teks, ikon, garis)
10%  →  Maroon & Kuning        (tombol, badge, aksen)
```

**Logikanya:** merah dan kuning itu warna "berteriak". Kalau dipakai sedikit, dia menarik perhatian ke hal penting (tombol beli, promo). Kalau dipakai banyak, semuanya berteriak dan pengguna jadi pusing. Aplikasi makanan yang sukses (GoFood, GrabFood, ShopeeFood) latarnya selalu didominasi putih — warna brand hanya muncul di header dan tombol.

**Yang BOLEH pakai blok warna besar:**
- Splash screen (boleh full maroon atau full kuning dengan logo)
- Header halaman profil / halaman promo (maroon di ~25% atas layar)
- Onboarding

**Yang TIDAK BOLEH:**
- Latar halaman daftar produk berwarna maroon/kuning penuh
- Semua tombol dalam satu layar berwarna maroon
- Teks panjang di atas latar kuning

---

## 5. Aturan Kontras (Wajib — Ini Soal Keterbacaan)

Kombinasi yang **AMAN** (lolos standar kontras WCAG AA):

| Latar | Teks | Status |
|---|---|---|
| Maroon `#7E1416` | Putih `#FFFFFF` | ✅ Sangat aman |
| Maroon `#7E1416` | Kuning `#F8E600` | ✅ Aman (hanya untuk teks besar/logo, jangan paragraf) |
| Putih `#FFFFFF` | Coklat gelap `#2D1B12` | ✅ Sangat aman |
| Putih `#FFFFFF` | Maroon `#7E1416` | ✅ Aman |
| Kuning `#F8E600` | Maroon gelap `#4A0A0C` | ✅ Aman |
| Kuning `#F8E600` | Coklat gelap `#2D1B12` | ✅ Aman |

Kombinasi yang **DILARANG**:

| Latar | Teks | Kenapa |
|---|---|---|
| Kuning `#F8E600` | Putih `#FFFFFF` | ❌ Tidak terbaca sama sekali |
| Kuning `#F8E600` | Abu-abu | ❌ Samar |
| Putih `#FFFFFF` | Kuning `#F8E600` | ❌ Tidak terbaca. Kuning JANGAN dipakai untuk teks di latar putih |
| Maroon `#7E1416` | Abu gelap / hitam | ❌ Terlalu gelap ketemu gelap |

> 💡 **Cara cepat mengingat:** Kuning = latar, bukan tinta. Kalau kuning jadi latar, tintanya harus maroon/coklat gelap.

---

## 6. Pemetaan ke Komponen UI

### AppBar / Header
- Latar: `maroon-700` `#7E1416`
- Judul & ikon: putih `#FFFFFF`
- Status bar: `maroon-900` `#4A0A0C`

### Tombol
| Jenis | Latar | Teks | Contoh |
|---|---|---|---|
| Primary (aksi utama) | `#7E1416` | `#FFFFFF` | "Pesan Sekarang", "Bayar" |
| Primary ditekan | `#A32226` | `#FFFFFF` | — |
| Primary disabled | `#D9CFC9` | `#9B948C` | — |
| Secondary (aksi kedua) | Putih + border `#7E1416` | `#7E1416` | "Lihat Detail", "Batal" |
| Text button | Transparan | `#7E1416` | "Lewati", "Lainnya" |

> ⚠️ Kuning **tidak dipakai untuk tombol utama** karena teks putih tidak terbaca di atasnya, dan teks gelap di atas kuning terang terasa seperti "peringatan". Kuning cukup untuk badge dan highlight.

### Kartu Produk
- Latar kartu: `#FDFBF2` (atau putih dengan shadow tipis)
- Nama produk: `#2D1B12`
- Harga: `#7E1416` (bold — harga adalah info penting, layak dapat warna brand)
- Badge diskon/promo: latar `#F8E600`, teks `#4A0A0C`
- Rating bintang: `#FFC107`

### Bottom Navigation
- Latar: putih `#FFFFFF`
- Ikon & label aktif: `#7E1416`
- Ikon & label nonaktif: `#9B948C`
- Indikator aktif (opsional): pill/garis `#F8E600`

### Input Field (Form)
- Latar: `#F2EFEA` atau putih dengan border `#D9CFC9`
- Border saat fokus: `#7E1416`
- Placeholder: `#9B948C`
- Teks isian: `#2D1B12`
- Border saat error: `#C62828`

### Chip / Filter Kategori
- Tidak dipilih: latar putih, border `#D9CFC9`, teks `#6B6259`
- Dipilih: latar `#7E1414`... → gunakan `#7E1416`, teks putih. Alternatif lembut: latar `#F6E3E3`, teks `#7E1416`

### Banner Promo
- Latar: `#FDF9D6` (kuning lembut) atau gradien `#F8E600 → #FFC107`
- Teks: `#4A0A0C`
- Tombol di dalam banner: maroon + teks putih

### Snackbar / Toast
- Sukses: latar `#2E7D32`, teks putih
- Error: latar `#C62828`, teks putih
- Netral: latar `#2D1B12`, teks putih

---

## 7. Contoh Kode Flutter (Siap Copy-Paste)

```dart
import 'package:flutter/material.dart';

/// Semua warna brand Roti Gembung Panglima.
/// Jangan hardcode hex di widget — selalu panggil dari sini.
class AppColors {
  AppColors._(); // supaya tidak bisa di-instantiate

  // ── Brand ──────────────────────────────────────
  static const maroon900 = Color(0xFF4A0A0C);
  static const maroon700 = Color(0xFF7E1416); // PRIMARY
  static const maroon500 = Color(0xFFA32226); // pressed/hover
  static const maroon100 = Color(0xFFF6E3E3);
  static const maroon50  = Color(0xFFFBF1F1);

  static const yellow500 = Color(0xFFF8E600); // SECONDARY
  static const yellow600 = Color(0xFFE5C400);
  static const gold500   = Color(0xFFFFC107); // rating, aksen
  static const yellow100 = Color(0xFFFDF9D6);
  static const yellow50  = Color(0xFFFEFCEA);

  // ── Netral ─────────────────────────────────────
  static const white        = Color(0xFFFFFFFF);
  static const creamSurface = Color(0xFFFDFBF2);
  static const grey100      = Color(0xFFF2EFEA);
  static const grey300      = Color(0xFFD9CFC9);
  static const grey400      = Color(0xFF9B948C);
  static const grey600      = Color(0xFF6B6259);
  static const textDark     = Color(0xFF2D1B12);

  // ── Status ─────────────────────────────────────
  static const success   = Color(0xFF2E7D32);
  static const successBg = Color(0xFFE8F3E9);
  static const error     = Color(0xFFC62828);
  static const errorBg   = Color(0xFFFBEAEA);
  static const warning   = Color(0xFFB26A00);
  static const warningBg = Color(0xFFFFF4E0);
  static const info      = Color(0xFF1565C0);
  static const infoBg    = Color(0xFFE7F0FA);
}

/// ThemeData siap pakai.
final ThemeData panglimaTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.white,
  colorScheme: const ColorScheme.light(
    primary: AppColors.maroon700,
    onPrimary: AppColors.white,
    secondary: AppColors.yellow500,
    onSecondary: AppColors.maroon900, // teks di atas kuning = gelap!
    surface: AppColors.creamSurface,
    onSurface: AppColors.textDark,
    error: AppColors.error,
    onError: AppColors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.maroon700,
    foregroundColor: AppColors.white,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.maroon700,
      foregroundColor: AppColors.white,
      disabledBackgroundColor: AppColors.grey300,
      disabledForegroundColor: AppColors.grey400,
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.white,
    selectedItemColor: AppColors.maroon700,
    unselectedItemColor: AppColors.grey400,
  ),
);
```

---

## 8. Do & Don't (Contoh Konkret)

✅ **DO**
- Latar putih, kartu putih gading, satu tombol maroon besar di bawah layar.
- Badge "PROMO 20%" kuning kecil di pojok foto produk.
- Harga ditulis maroon bold: **Rp 15.000**.
- Beri ruang kosong (padding) yang lega — minimal 16dp di tepi layar.
- Foto roti dibiarkan tampil dominan; warna UI mendukung, bukan bersaing.

❌ **DON'T**
- Latar halaman full kuning `#F8E600` dengan teks putih. (Tidak terbaca + menyilaukan.)
- Tiga tombol maroon berjejer dalam satu layar. (Pengguna bingung mana yang penting.)
- Teks kuning di atas latar putih. (Nyaris tak terlihat.)
- Pakai hitam murni `#000000` untuk teks. (Pakai `#2D1B12`.)
- Pakai maroon untuk pesan error. (Pakai `#C62828` supaya beda dari warna brand.)
- Menambah warna baru (biru, hijau terang, ungu) untuk dekorasi. Warna di luar dokumen ini hanya untuk status (sukses/error/warning/info).

---

## 9. Catatan Kenyamanan Pengguna (UX)

1. **Warna hangat = selera makan.** Merah dan kuning terbukti membangkitkan rasa lapar — itulah kenapa hampir semua brand makanan memakainya. Tapi porsinya harus kecil (aturan 60/30/10) supaya efeknya "menggoda", bukan "melelahkan".
2. **Putih dominan = kesan bersih & higienis.** Untuk produk makanan, kesan bersih itu penting banget bagi kepercayaan pembeli.
3. **Konsistensi > kreativitas.** Pengguna belajar bahwa "maroon = bisa diklik". Kalau tiba-tiba ada tombol kuning atau hijau, mereka ragu. Pertahankan pola.
4. **Foto produk harus tetap hangat.** Jangan beri filter gelap/dingin pada foto roti — foto yang hangat dan cerah membuat produk terlihat lebih lezat.
5. **Uji di HP asli, di luar ruangan.** Kuning `#F8E600` bisa terlihat sangat berbeda di bawah sinar matahari. Kalau silau, turunkan ke `#E5C400` untuk elemen tersebut.
6. **Dark mode (opsional, nanti saja).** Kalau suatu saat dibuat: latar `#1A1210` (coklat sangat gelap, bukan hitam), maroon dinaikkan terangnya ke `#C4494D`, kuning tetap sebagai aksen kecil. Jangan sekadar membalik warna.

---

## 10. Referensi Cepat untuk AI Assistant

Kalau kamu adalah AI yang diminta membuat UI untuk aplikasi ini, ikuti template prompt-mental berikut:

```
Background layar: #FFFFFF
Kartu/panel: #FDFBF2, sudut membulat, shadow tipis
Teks utama: #2D1B12 | Teks sekunder: #6B6259
AppBar: #7E1416 dengan teks/ikon putih
Tombol utama (maks. 1 per layar): #7E1416, teks putih, sudut membulat
Harga & elemen penting: #7E1416
Badge promo: latar #F8E600, teks #4A0A0C
Rating: #FFC107
Error: #C62828 | Sukses: #2E7D32
Dilarang: teks putih di atas kuning, teks kuning di atas putih,
latar maroon/kuning memenuhi layar, hitam murni #000000.
```

---

*Dokumen v1.0 — dibuat berdasarkan logo resmi Roti Gembung Panglima. Jika logo diperbarui, sesuaikan kembali nilai hex pada bagian 2 dan 3.*
