# Demo Aplikasi — Roti Gembung Panglima (Patch 1)

Dokumen ini merangkum kondisi **demo Patch 1** aplikasi **Roti Gembung Panglima (RGP)**:
tampilan tiap halaman, fitur lintas halaman, dan **alur checkout dari awal hingga akhir**.

> **Status Patch 1:** seluruh data masih **dummy lokal** (`Env.useDummyData = true`).
> Belum ada koneksi backend/pembayaran nyata — fokusnya adalah UI/UX & alur lengkap.
> Semua layar sudah lolos `flutter analyze` (bersih) dan 4 widget test (hijau).

---

## 1. Ringkasan Produk

Aplikasi pemesanan roti gembung/roti/kopi ala Kopi Kenangan, dengan identitas brand
**maroon–kuning–emas**. Pengguna dapat menjelajah menu, menambah ke keranjang,
memilih **Pickup / Delivery**, dan menyelesaikan pembayaran.

| Aspek | Keterangan |
|---|---|
| Platform | Flutter (Material 3), target Android/iOS |
| Navigasi | Bottom navigation 5 tab + halaman detail yang di-`push` |
| Data | Dummy lokal (`DummyData`) — siap diganti API (Dio sudah disiapkan) |
| Penyimpanan | Keranjang **tersimpan di lokal HP** (`shared_preferences`) |
| Lokasi | OpenStreetMap (`flutter_map`) + Nominatim + GPS (`geolocator`) |
| Brand warna | Maroon `#7E1416` (primary), Kuning `#F8E600`, Emas `#FFC107` |

**Navigasi utama (bottom bar):**

`Beranda` · `Menu` · `VIP` · `History` · `Profile`

---

## 2. Halaman per Halaman

### 2.1 Beranda
Header **menciut saat di-scroll** (collapsing header) + konten feed.

- **Header (pinned):**
  - Pill loyalty: **Gold 10%** & **600 pts**.
  - Kartu lokasi outlet (ketuk → pilih outlet via halaman *Method*).
  - Info layanan: titik **Delivery** (hijau) & **Pickup** (biru).
  - Saat di-scroll: pill & alamat menghilang halus, Delivery/Pickup masuk ke dalam kartu.
- **Carousel promo** (3 banner: diskon harian, gratis kopi, paket hemat).
- **Quick Actions** — 2 kartu aksi (Order, Delivery) dengan ikon kontras.
- **Order Lagi** — daftar horizontal produk yang sering dibeli.
- **Voucher banner** (garis putus-putus).
- **Seksi produk:** *Spesial Hari Ini* (promo) · *Baru!* · **grid Makanan**.
- **Kartu kontak** outlet.
- **Tarik-untuk-refresh** aktif.

### 2.2 Menu
Meniru menu Kopi Kenangan: pilih outlet, tab kategori tersinkron scroll, grid 2 kolom.

- **Selektor outlet** di atas (ketuk → halaman *Method* Pickup/Delivery).
- **Tab kategori** (scroll-spy: tab aktif mengikuti posisi scroll, ketuk tab → loncat ke seksi):
  *Promo & Combo*, *Baru!*, *Roti Gembung*, *Roti*, *Makanan*, *Minuman*.
- **Grid produk 2 kolom** per kategori. **Tarik-untuk-refresh** aktif.
- Setiap kartu produk **bisa diketuk** → halaman Detail Produk.

**Kartu produk (komponen bersama Beranda & Menu):**
foto **mengisi ruang dominan** (± 60% kartu, tanpa ruang kosong), lalu nama (2 baris,
seragam antar kartu) + harga (harga coret bila promo). Ukuran sel diatur satu tempat
via `ProductCard.cellExtent`.

### 2.3 Detail Produk
Dibuka saat kartu produk diketuk.

- **Hero gambar** penuh + tombol bulat *Back* & *Share*.
- Nama + harga (harga coret bila promo) + deskripsi.
- **"Supaya kamu hemat"** — upsell paket (dapat diketuk ke detail paket).
- **"Catatan Tambahan"** — kolom catatan dengan penghitung `0/100`.
- **Bilah bawah:** stepper jumlah `– n +` + tombol **`+ Keranjang Rp…`**
  (menambah ke keranjang lalu kembali).

### 2.4 VIP ("Panglima VIP")
Halaman keanggotaan berjenjang.

- **Carousel kartu tier** (geser): **Silver** (sebelumnya) → **Gold** (saat ini, 10%) → **Black** (terkunci).
  Latar halaman berganti warna mengikuti tier aktif; kartu berisi nama tier, badge,
  sapaan (Hai, Salia), poin `1.023.450 / target`, progress bar, dan lambang.
- **Tab (isi berbeda per tier):**
  - **Voucher** — kolom kode voucher, "Diskon & Cashback" (klaim ongkir), chip filter
    (Semua/Diskon/Cashback/Delivery yang benar-benar memfilter), daftar voucher.
  - **Voucher Pack** — paket langganan voucher (harga coret, "Hemat %", Beli Paket).
  - **Benefit** — daftar keuntungan tier (untuk **Black** tampil terkunci + info naik level).
- **Tarik-untuk-refresh** aktif.

### 2.5 History
Riwayat pesanan yang sudah tuntas.

- Daftar kartu pesanan (id, item, total, waktu).
- Karena pesanan yang sudah dibayar **tidak bisa dibatalkan**, tag status diganti
  tombol **"Beli Lagi"** (pesan ulang → menambah ke keranjang).
- **Tarik-untuk-refresh** aktif.

### 2.6 Profile ("Saya")
- **Header sapaan** + kartu statistik: **Level (Gold 10%)** & **Panglima Points (600 pts)**.
- **Daily Check-In** 7 hari (poin & voucher harian).
- **Grup menu:** *Akun* (kotak masuk, alamat, biometrik, bahasa…),
  *Pesan* (riwayat, metode bayar, pesanan besar), *Roti Gembung Panglima* (bantuan,
  kebijakan, WhatsApp, dll), tombol **Keluar**, versi aplikasi.
- **Tarik-untuk-refresh** aktif.

### 2.7 Halaman Pendukung
- **Method (Pickup/Delivery)** — pemilih outlet (Pickup) atau alamat (Delivery) dengan
  pencarian, **"Gunakan lokasi saat ini" (GPS)**, dan **pilih di peta (OSM)**.
- **Form Alamat** — detail alamat, nama alamat, penerima, dll.
- **Map Picker** — memilih titik antar di peta + reverse-geocoding alamat.

---

## 3. Fitur Lintas Halaman

- **Bilah keranjang mengambang** — selalu tampil **di atas bottom navbar** selama
  keranjang berisi (menampilkan `N produk` + total). Ketuk → **Konfirmasi Pesanan**.
- **Tarik-untuk-refresh** — di semua tab (ikon panah berputar maroon).
- **Status bar adaptif** — ikon **hitam** di halaman terang, **putih** di AppBar maroon.
- **Keranjang persisten** — isi keranjang **tidak hilang saat aplikasi ditutup**
  (disimpan ke `shared_preferences`, dimuat saat start).

---

## 4. Proses Checkout — Awal hingga Akhir

Alur inti Patch 1, dari memilih produk sampai pembayaran selesai.

### Langkah 1 — Pilih produk
Dari **Beranda** atau **Menu**, ketuk kartu produk → **Detail Produk**.
Atur **jumlah** dan **catatan** (opsional).

### Langkah 2 — Tambah ke keranjang
Tekan **`+ Keranjang Rp…`**. Produk masuk keranjang (**tersimpan di lokal HP**),
halaman kembali, dan **bilah keranjang** muncul di atas navbar.

### Langkah 3 — Buka Konfirmasi Pesanan
Ketuk **bilah keranjang** → halaman **Konfirmasi Pesanan**. Pilih metode:

- **Pickup** — kartu **outlet** (tombol *Ubah*).
- **Delivery** — kartu **outlet** + kartu **alamat** (masing-masing *Ubah*),
  **banner upsell ongkir**, dan baris **Instant Delivery** (Rp 10.500) yang muncul
  setelah alamat terpilih. Total Delivery **sudah termasuk ongkir**.

Di sini pengguna bisa **Ubah jumlah/hapus item**, **Ganti** catatan item,
**Tambah Pesanan** (kembali ke Menu), atau **Pakai Kode Voucher**.
Bilah bawah menampilkan **Total** + tombol **Pilih Pembayaran**.

### Langkah 4 — Konfirmasi metode
Tekan **Pilih Pembayaran** → muncul **modal konfirmasi** (variasi Pickup/Delivery)
berisi ringkasan outlet/rute + tombol **"Ya, Sudah Benar"**.

### Langkah 5 — Halaman Checkout
Setelah dikonfirmasi → **Checkout** (AppBar putih, judul hitam):

1. **Kartu rute/outlet** — Delivery: *Outlet → Dikirim ke* alamat; Pickup: *Outlet + Opsi Pickup*.
2. **Panglima Points** — checkbox *Redeem 600 pts* (1 poin = 1 rupiah; mengurangi total).
3. **Pembayaran Langsung** — kartu metode (QRIS, ShopeePay, blu by BCA, GoPay, OVO, DANA, Tunai)
   + **Lihat Semua**.
4. **Pesan** — ringkasan item + jumlah.
5. **Delivery:** banner *"Pastikan nomor kamu dapat dihubungi…"* + **Instant Delivery** (estimasi 25–40 min).
   **Pickup:** opsi **Kantung Belanja** (checkbox Rp 1.000).
6. **Pakai Kode Voucher**.
7. **Rincian pembayaran:** Subtotal · Delivery Fee · Take Away Charge · (Redeem) ·
   **Loyalty Cashback** (bonus poin, +) · **Total Pembayaran**.
8. **Bilah bawah:** Pickup → **Jadwalkan** + **Bayar - Rp…**; Delivery → **Bayar - Rp…**.

**Modal pendukung di Checkout:**
- **Keluar Halaman Ini?** — muncul saat menekan back (Keluar / Lanjutkan Bayar).
- **Jadwalkan Pickup** — roda pemilih slot waktu (Pickup Sekarang / Lanjut).
- **Lihat Semua** — daftar seluruh metode pembayaran.

### Langkah 6 — Bayar (selesai)
Tekan **Bayar - Rp…** → pilih metode → **keranjang dikosongkan**, kembali ke Home
(tab **History**), dan muncul konfirmasi *"Pesanan dibayar…"*.

> **Diagram singkat**
> `Menu/Beranda → Detail Produk → + Keranjang → Bilah Keranjang → Konfirmasi Pesanan
> → (Pilih Pembayaran) → Konfirmasi Metode → Checkout → Bayar → Selesai (History)`

---

## 5. Rincian Biaya (dummy — `lib/core/config/fees.dart`)

| Komponen | Nilai | Berlaku |
|---|---|---|
| Instant Delivery (ongkir) | Rp 10.500 | Delivery |
| Take Away Charge (kemasan) | Rp 1.500 | Delivery |
| Kantung Belanja (opsional) | Rp 1.000 | Pickup |
| Loyalty Cashback | 4,5% dari subtotal | Bonus poin (tidak mengurangi bayar) |
| Ambang diskon ongkir (upsell) | Rp 120.000 | Delivery |

> Nilai ongkir & estimasi masih **flat dummy** — pada patch berikutnya diganti
> **estimasi nyata dari API Grab** di alur pembayaran.

---

## 6. Arsitektur & Teknis

```
lib/
├─ main.dart                 # entry; muat keranjang lokal
├─ app.dart                  # MaterialApp + tema
├─ widget_tree.dart          # 5 tab (IndexedStack) + navbar + bilah keranjang
├─ core/
│  ├─ config/  env.dart, fees.dart
│  ├─ network/ dio_client.dart, api_error.dart    # siap untuk API
│  ├─ theme/   app_colors.dart, app_theme.dart
│  └─ utils/   formatter.dart                      # Rupiah, tanggal, poin
├─ data/
│  ├─ dummy/dummy_data.dart  # sumber data dummy
│  ├─ models/  product, order, cart_item, vip, saved_address, ...
│  ├─ cart_store.dart        # keranjang + persistensi lokal
│  ├─ address_store.dart     # daftar alamat
│  ├─ notifiers.dart         # tab aktif (ValueNotifier)
│  ├─ location_service.dart, geocoding_service.dart
├─ pages/    beranda, menu, product_detail, cart, checkout, method,
│            vip, history, profile, address_form, map_picker
└─ widgets/  product_card, cart_bar, navbar_widget, order_card, app_top_bar, dashed_border
```

- **State ringan** via `ValueNotifier` (`selectedPageNotifier`, `cartStore`, `addressStore`)
  + `ValueListenableBuilder` — UI ikut ter-update otomatis.
- **Persistensi keranjang** best-effort (gagal diabaikan agar tak mengganggu, mis. saat test).
- **Dio** sudah dikonfigurasi (base URL, header) namun **belum dipakai** — tinggal
  mengganti pemanggilan `DummyData` dengan repository saat API siap.

**Data dummy utama:** 4 outlet (Samarinda/Balikpapan/Tenggarong/Bontang),
15 produk (Roti Gembung, Roti, Makanan, Minuman, Paket), loyalty **Gold 10% / 600 pts**,
member VIP **Salia** (1.023.450 pts).

---

## 7. Sudah vs Belum (untuk Patch berikutnya)

**Sudah (Patch 1):**
- Seluruh UI/UX: Beranda, Menu, Detail, VIP, History, Profile, Method, Alamat, Peta.
- Keranjang + persistensi lokal + bilah keranjang mengambang.
- Alur Konfirmasi Pesanan (Pickup/Delivery) → Checkout → Bayar lengkap dengan modal.
- Pull-to-refresh, status bar adaptif, tema brand konsisten.

**Belum (rencana lanjutan):**
- Integrasi **backend nyata** (menu, pesanan, poin) menggantikan `DummyData`.
- **Ongkir & estimasi Instant Delivery via API Grab** di halaman pembayaran.
- **Payment gateway** nyata (QRIS/e-wallet/kartu).
- Autentikasi/akun, notifikasi, pelacakan pesanan real-time.
- Fungsi voucher & redeem poin yang tersambung server.

---

*Dokumen ini menggambarkan build demo Patch 1. Semua angka/harga bersifat contoh (dummy).*
