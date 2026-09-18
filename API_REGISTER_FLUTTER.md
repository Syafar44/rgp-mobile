 # Panduan Integrasi: Pendaftaran & Verifikasi Email (untuk Tim Flutter)

Dokumen ini menjelaskan alur pendaftaran customer end user PRG lewat API,
supaya bisa diintegrasikan ke aplikasi Flutter tanpa perlu membaca kode Go-nya.

---

## ⚠️ PALING PENTING: Token JWT MEMBEKU saat login — wajib panggil `/auth` ulang setelah verifikasi

Ini bukan catatan kaki, ini langkah **wajib** dalam alur.

Status `email_verified` disematkan di dalam token JWT saat pengguna login lewat
`POST /auth`, dan token itu **berlaku 24 jam**. Nilainya diambil dari database
**pada saat login itu terjadi** dan tidak pernah diperbarui otomatis selama
token itu masih berlaku.

Artinya: bila pengguna login sebelum memverifikasi email, lalu berhasil
memverifikasi lewat `POST /verify_email`, token yang sedang dipegang aplikasi
**tetap membawa `email_verified: false`** — walaupun di database status itu
sudah `true`. Bila aplikasi tidak melakukan apa pun, pengguna akan terlihat
belum terverifikasi sampai token itu kedaluwarsa (bisa sampai 24 jam).

**Solusi wajib:** tepat setelah `POST /verify_email` membalas sukses, aplikasi
**HARUS** memanggil `POST /auth` lagi (dengan email + password yang sama) untuk
mendapatkan token baru yang membawa `email_verified: true`, lalu menyimpannya
menggantikan token lama. Jangan hanya mengandalkan response `/verify_email` —
response itu tidak berisi token maupun klaim `email_verified`.

Ringkas alurnya:

```
login (/auth) → token lama, email_verified mungkin false
       │
       ▼
pengguna mengetik kode OTP → POST /verify_email → 200 OK
       │
       ▼
   PANGGIL /auth LAGI (wajib, otomatis, tanpa pengguna harus login manual lagi)
       │
       ▼
token baru → email_verified: true → tombol transaksi (nanti) boleh muncul
```

---

## ⚠️ PENTING: `email_verified` BELUM ditegakkan di server pada rilis ini

Pada rilis ini, **belum ada satu pun endpoint transaksi** (checkout, buat
pesanan, dsb.) di API. Karena itu, **tidak ada tempat di server yang memeriksa
`email_verified` sebelum mengizinkan transaksi** — karena transaksinya sendiri
belum ada.

Konsekuensinya untuk tim Flutter:

- Menyembunyikan tombol "Belanja"/"Checkout" di aplikasi berdasarkan
  `email_verified == false` adalah **kenyamanan pengguna** (UX yang mengarahkan
  pengguna untuk verifikasi dulu), **BUKAN pengaman**.
- Jangan menganggap bahwa "toh sudah ada flag `email_verified`, jadi belanja
  sudah aman dikunci". Siapa pun yang memanggil API secara langsung (bukan
  lewat aplikasi Flutter) tidak tertahan oleh flag ini sama sekali hari ini.
- Saat endpoint transaksi dibuat di rilis berikutnya, endpoint itu wajib
  memeriksa sendiri status verifikasi di server. Sampai saat itu, anggap flag
  ini murni sinyal UI.

---

## Daftar Endpoint

| Method | Path | Auth | Rate limit |
|---|---|---|---|
| `POST` | `/register` | publik | 6/menit per IP (jatah gabungan dengan `/resend_verify`, lihat catatan di bawah) |
| `POST` | `/verify_email` | publik | 30/menit per IP |
| `POST` | `/resend_verify` | publik | 6/menit per IP (jatah gabungan dengan `/register`) + 3/jam per alamat email |
| `POST` | `/auth` | publik (butuh header `apikey`) | 1000/detik per IP (limiter global, longgar) |
| `GET` | `/me` | butuh JWT (`Authorization: Bearer <token>`) | limiter global |

---

## Alur Lengkap: Pendaftaran sampai Bisa Bertransaksi

```
1. POST /register
   → akun users + customers dibuat, TANPA token login
   → kode OTP 6 digit dikirim ke email (berlaku 15 menit)
        │
        ▼
2. Aplikasi memanggil POST /auth (email + password yang baru didaftarkan)
   → dapat token. Boleh dipakai login walau belum verifikasi
     (email_verified: false di dalamnya) — aplikasi boleh menampilkan
     katalog dsb., tapi sebaiknya arahkan ke layar "verifikasi email"
        │
        ▼
3. Pengguna membuka email, mengetik 6 digit kode di aplikasi
        │
        ▼
4. POST /verify_email {email, code}
   → 200 OK bila kode benar (atau bila sebelumnya sudah terverifikasi)
        │
        ▼
5. WAJIB: Aplikasi memanggil POST /auth LAGI (email + password sama)
   → token BARU, kali ini email_verified: true
        │
        ▼
6. Aplikasi menyimpan token baru menggantikan yang lama
   → tombol transaksi (bila sudah ada di rilis mendatang) boleh ditampilkan
```

Bila pengguna tidak menerima kode (email tidak sampai, kode kedaluwarsa 15
menit), aplikasi memanggil `POST /resend_verify` untuk meminta kode baru, lalu
kembali ke langkah 3.

---

## Referensi Endpoint

### `POST /register`

Mendaftarkan customer end user baru. Publik, tidak butuh token apa pun.

**Contoh request:**

```json
{
  "name": "Budi Santoso",
  "email": "budi@contoh.com",
  "password": "rahasia123",
  "contact": "081234567890",
  "address": "Jl. Merdeka No. 10, Samarinda"
}
```

**Aturan field:**

| Field | Wajib | Aturan |
|---|---|---|
| `name` | ya | maksimal 255 karakter |
| `email` | ya | format email valid, maksimal 255 karakter. Disimpan huruf kecil semua di server, jadi `Budi@Contoh.com` dan `budi@contoh.com` dianggap alamat yang sama |
| `password` | ya | minimal 8 karakter, **maksimal 72 karakter** — batas ini bukan angka sembarangan: algoritma hashing password (bcrypt) di server hanya memakai 72 byte pertama dan diam-diam mengabaikan sisanya, jadi server menolak di depan daripada menerima password panjang yang sebagian isinya tidak pernah berpengaruh |
| `contact` | ya | 8–20 karakter |
| `address` | ya | maksimal 500 karakter |

**Contoh response sukses (`201 Created`):**

```json
{
  "message": "Success",
  "data": {
    "id": 55,
    "name": "Budi Santoso",
    "email": "budi@contoh.com",
    "code": "CUS1789012345678"
  }
}
```

Catatan: response ini **tidak berisi token login**. Setelah mendaftar,
aplikasi tetap harus memanggil `POST /auth` untuk mendapatkan token (lihat
diagram alur di atas).

**Tabel kode error:**

| HTTP | `message` | Saat terjadi | Apa yang ditampilkan ke pengguna |
|---|---|---|---|
| `400` | `"error validation"` + field `validation` (map nama field → nama aturan yang dilanggar, contoh `{"email": "email", "password": "min"}`) | Salah satu field tidak lolos aturan | Tampilkan pesan per field sesuai aturan yang dilanggar, contoh "Password minimal 8 karakter" bila `validation.password == "min"` |
| `409` | `"email sudah terdaftar"` | Alamat email sudah dipakai akun lain | "Email ini sudah terdaftar. Coba masuk, atau gunakan email lain." |
| `429` | *(bukan JSON object — lihat catatan)* | Melebihi 6 percobaan pendaftaran per menit dari IP yang sama (jatah ini gabungan dengan `/resend_verify`) | "Terlalu banyak percobaan pendaftaran. Coba lagi beberapa saat lagi." |
| `503` | `"layanan verifikasi sedang tidak tersedia, coba lagi sebentar lagi"` | Layanan penyimpan kode OTP sedang bermasalah — server sengaja TIDAK membuat akun dalam kondisi ini | "Server sedang bermasalah, coba lagi sebentar lagi." |
| `500` | pesan galat teknis | Kegagalan tak terduga di server | "Terjadi kesalahan, coba lagi nanti." |

**Contoh `curl`:**

```bash
curl -X POST https://api.example.com/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Budi Santoso",
    "email": "budi@contoh.com",
    "password": "rahasia123",
    "contact": "081234567890",
    "address": "Jl. Merdeka No. 10, Samarinda"
  }'
```

---

### `POST /verify_email`

Memeriksa kode OTP 6 digit dan menandai email sebagai terverifikasi. Publik.

**Contoh request:**

```json
{ "email": "budi@contoh.com", "code": "482913" }
```

**Aturan field:**

| Field | Wajib | Aturan |
|---|---|---|
| `email` | ya | format email valid |
| `code` | ya | tepat 6 digit angka |

**Contoh response sukses (`200 OK`):**

```json
{
  "message": "Success",
  "data": { "verified_at": "2026-09-10T14:03:21Z" }
}
```

Bila email yang sama sudah pernah terverifikasi sebelumnya, endpoint ini tetap
membalas `200` dengan waktu verifikasi yang lama, **tanpa memeriksa kode sama
sekali** — jadi aman dipanggil dua kali (misalnya pengguna menekan tombol
"Verifikasi" dua kali karena koneksi lambat).

**⚠️ PENTING soal `verified_at`: akhiran `Z` BUKAN berarti UTC.** Kolom ini
disimpan di database sebagai `timestamp without time zone` dan diisi memakai
waktu lokal server (WITA, UTC+8), bukan UTC. Driver database yang dipakai
server memformat nilai ini dengan akhiran `Z` (format yang biasanya menandai
UTC), tapi di sini itu menyesatkan — nilainya tetap waktu lokal server apa
adanya. **Jangan** memperlakukan `verified_at` sebagai waktu UTC dan
mengonversinya ke zona waktu perangkat pengguna, karena hasilnya akan meleset
8 jam. Tampilkan nilainya apa adanya (atau ambil bagian tanggal/jamnya saja
tanpa konversi zona waktu).

**JANGAN LUPA:** setelah response ini `200`, aplikasi wajib memanggil
`POST /auth` lagi (lihat peringatan paling atas dokumen ini) untuk mendapat
token baru yang membawa `email_verified: true`.

**Tabel kode error:**

| HTTP | `message` | Saat terjadi | Apa yang ditampilkan ke pengguna |
|---|---|---|---|
| `400` | `"error validation"` + field `validation` | Format email/code salah (misalnya code bukan 6 digit) | Pesan per field, contoh "Kode harus 6 digit angka" |
| `400` | `"kode verifikasi salah"` | Kode yang diketik tidak cocok | "Kode salah, coba periksa lagi." |
| `400` | `"kode verifikasi tidak berlaku, minta kirim ulang"` | Kode sudah kedaluwarsa (>15 menit), tidak pernah ada, **atau email tidak terdaftar** — server sengaja tidak membedakan ketiganya supaya tidak bisa dipakai menebak email mana yang terdaftar | "Kode sudah tidak berlaku. Minta kirim ulang kode." |
| `429` | `"terlalu banyak percobaan, minta kode baru"` | Sudah 5 kali salah memasukkan kode untuk kode yang sama — kode itu langsung dibatalkan di server | "Terlalu banyak percobaan salah. Minta kode baru lewat 'Kirim ulang'." |
| `429` (bukan JSON object — body `null`) | — | Melebihi 30 permintaan per menit dari IP yang sama (limiter IP, jarang tersentuh pengguna wajar) | "Terlalu banyak percobaan, coba lagi sebentar lagi." |
| `503` | `"layanan verifikasi sedang tidak tersedia, coba lagi sebentar lagi"` | Layanan penyimpan kode OTP bermasalah | "Server sedang bermasalah, coba lagi sebentar lagi." |
| `500` | pesan galat teknis | Kegagalan tak terduga | "Terjadi kesalahan, coba lagi nanti." |

Perhatikan: kode dibatasi **5 kali percobaan gagal per kode**, bukan per menit.
Ini berbeda dari batas per-IP di atas — lihat bagian "Tiga Jenis Batas Laju"
di bawah untuk penjelasan lebih lengkap.

**Contoh `curl`:**

```bash
curl -X POST https://api.example.com/verify_email \
  -H "Content-Type: application/json" \
  -d '{ "email": "budi@contoh.com", "code": "482913" }'
```

---

### `POST /resend_verify`

Mengirim ulang kode verifikasi. Publik.

**⚠️ Endpoint ini SELALU membalas sama, baik email terdaftar maupun tidak.**
Ini disengaja: kalau responsnya berbeda (misalnya `404` untuk email tak
terdaftar), siapa pun bisa memakai endpoint ini untuk menebak alamat email mana
saja yang punya akun di sistem PRG. **Jangan pernah memakai response endpoint
ini untuk mengecek apakah suatu email sudah terdaftar** — misalnya jangan
membuat fitur "cek email sudah pakai belum" berdasarkan endpoint ini, karena
hasilnya akan selalu sama.

**Contoh request:**

```json
{ "email": "budi@contoh.com" }
```

**Aturan field:**

| Field | Wajib | Aturan |
|---|---|---|
| `email` | ya | format email valid |

**Contoh response sukses (`200 OK`) — selalu sama:**

```json
{ "message": "Bila email terdaftar, kode verifikasi sudah dikirim" }
```

Response ini dikembalikan baik untuk email yang benar-benar terdaftar dan
belum terverifikasi (kode baru benar-benar dikirim), maupun untuk email yang
tidak terdaftar sama sekali atau yang sudah terverifikasi (tidak ada apa pun
yang dikirim). Dari sisi aplikasi, ketiga kondisi ini **tidak bisa
dibedakan** — dan memang tidak dirancang untuk bisa dibedakan.

**Tabel kode error:**

| HTTP | `message` | Saat terjadi | Apa yang ditampilkan ke pengguna |
|---|---|---|---|
| `400` | `"error validation"` + field `validation` | Format email salah | "Format email tidak valid." |
| `429` | `"terlalu banyak permintaan kode, coba lagi satu jam lagi"` | Alamat email yang sama sudah meminta kirim ulang lebih dari 3 kali dalam satu jam | "Sudah terlalu sering meminta kode. Coba lagi 1 jam lagi." |
| `429` (bukan JSON object — body `null`) | — | Melebihi 6 permintaan per menit dari IP yang sama (jatah ini gabungan dengan `/register`, lihat bagian "Tiga Jenis Batas Laju") | "Terlalu banyak percobaan, coba lagi sebentar lagi." |
| `503` | `"layanan verifikasi sedang tidak tersedia, coba lagi sebentar lagi"` | Layanan penyimpan kode OTP bermasalah | "Server sedang bermasalah, coba lagi sebentar lagi." |
| `500` | pesan galat teknis | Kegagalan tak terduga | "Terjadi kesalahan, coba lagi nanti." |

**Contoh `curl`:**

```bash
curl -X POST https://api.example.com/resend_verify \
  -H "Content-Type: application/json" \
  -d '{ "email": "budi@contoh.com" }'
```

---

### `POST /auth` (endpoint lama, ada perubahan)

Login. Butuh header `apikey` (nilai rahasia yang sama untuk semua klien resmi
— tanyakan ke tim backend, bukan bagian dari alur pendaftaran ini).

**Contoh request:**

```json
{ "email": "budi@contoh.com", "password": "rahasia123" }
```

**Perubahan pada response dibanding sebelumnya: field baru `email_verified`.**

**Contoh response sukses (`200 OK`) untuk customer end user hasil `/register`:**

```json
{
  "message": "Success",
  "data": {
    "id": "55",
    "name": "Budi Santoso",
    "email": "budi@contoh.com",
    "email_verified": false,
    "department": "",
    "roles": "Customer - End User",
    "token": "eyJhbGciOi...",
    "customer": ["123"],
    "customer_info": [
      { "id": "123", "address": "Jl. Merdeka No. 10, Samarinda", "lat": "", "long": "" }
    ]
  }
}
```

**Field yang wajib dipahami tim Flutter:**

- **`email_verified`** (`boolean`): status verifikasi email **pada saat token
  ini dibuat**. Nilai ini juga ikut disematkan ke dalam token JWT itu sendiri
  (bukan hanya di body response), dan **tidak berubah otomatis** selama token
  itu masih berlaku (24 jam) — lihat peringatan di paling atas dokumen ini.

- **`customer`** (array of string): untuk akun customer end user hasil
  `/register`, array ini berisi **satu id customer milik akun itu sendiri**
  (contoh: `["123"]`). Untuk akun **karyawan** (bukan customer end user maupun
  kasir outlet), nilainya adalah `["*"]` — tanda khusus yang berarti "seluruh
  customer, tanpa dibatasi", dipakai untuk peran internal yang memang perlu
  melihat semua customer. **Jangan** memperlakukan `"*"` sebagai id customer
  sungguhan (misalnya jangan mengirimnya sebagai `customer_id` ke endpoint
  lain) — itu adalah penanda "tanpa batas", bukan id.

**Tabel kode error (ringkas, hanya yang relevan untuk alur pendaftaran):**

⚠️ Handler `/auth` menimpa beberapa kode HTTP yang sebenarnya ditentukan di
lapisan service sebelum sampai ke klien. Tabel di bawah ini adalah apa yang
**benar-benar diterima aplikasi Flutter**, bukan apa yang secara internal
dihitung server — jangan menyiapkan penanganan untuk kode selain yang tertulis
di sini, karena kode itu tidak akan pernah muncul di response `/auth`.

| HTTP | `message` yang benar-benar dikirim | Saat terjadi | Apa yang ditampilkan ke pengguna |
|---|---|---|---|
| `403` | `"User tidak di temukan !"` | Password salah **atau** email tidak terdaftar — kedua kasus ini digabung menjadi respons yang sama persis; **`404` TIDAK PERNAH dikirim ke klien** untuk email yang tidak ditemukan, walau secara internal server sempat menghitungnya sebagai 404 sebelum ditimpa jadi 403 | "Email atau password salah." (jangan bocorkan mana yang salah) |
| `403` | `"Email dan password tidak sesuai"` | `apikey` header tidak valid, **atau** galat internal server (misalnya database tidak bisa diakses) — kedua kasus ini juga digabung menjadi respons yang sama; kode `401` (apikey salah) maupun `500` (galat internal) yang dihitung di lapisan service **tidak pernah sampai ke klien**, keduanya selalu muncul sebagai `403` dengan pesan ini | "Terjadi kesalahan saat login, coba lagi." |

**Contoh `curl`:**

```bash
curl -X POST https://api.example.com/auth \
  -H "Content-Type: application/json" \
  -H "apikey: <API_KEY_APLIKASI>" \
  -d '{ "email": "budi@contoh.com", "password": "rahasia123" }'
```

---

### `GET /me` (endpoint lama, ada perubahan)

Mengembalikan data dari klaim token JWT yang sedang dipakai. Butuh header
`Authorization: Bearer <token>`.

**Perubahan: field baru `email_verified` di `data`.**

**Contoh response sukses (`200 OK`):**

```json
{
  "message": "success",
  "data": {
    "userid": 55,
    "name": "Budi Santoso",
    "email": "budi@contoh.com",
    "email_verified": false,
    "department": "",
    "roles": "Customer - End User",
    "customer": ["123"]
  }
}
```

Karena `/me` membaca dari klaim token (bukan query database baru),
`email_verified` di sini **membawa nilai yang sama persis dengan saat token itu
dibuat** — bila token belum diperbarui setelah verifikasi, `/me` juga akan
tetap melaporkan `false`. Ini konsekuensi langsung dari poin "token JWT
membeku" di atas: `/me` bukan cara untuk mendapat status verifikasi terkini,
ia hanya membaca ulang apa yang sudah ada di token.

**Contoh `curl`:**

```bash
curl https://api.example.com/me \
  -H "Authorization: Bearer eyJhbGciOi..."
```

---

## Bentuk Galat Validasi (`400`)

`/register`, `/verify_email`, dan `/resend_verify` memakai bentuk galat
validasi yang **sama persis**:

```json
{
  "message": "error validation",
  "validation": {
    "email": "email",
    "password": "min"
  }
}
```

- `message` selalu bertuliskan `"error validation"` (bukan pesan dalam bahasa
  Indonesia) bila responsnya adalah galat validasi field.
- `validation` adalah map: **nama field (huruf kecil) → nama aturan yang
  dilanggar** untuk field itu. Nama field diambil dari nama field di struct Go
  (di-lowercase-kan), bukan dari nama JSON — tapi untuk keempat endpoint di
  atas kebetulan sama (`name`, `email`, `password`, `contact`, `address`,
  `code`).
- Nama aturan yang mungkin muncul: `required` (field kosong), `email` (format
  email salah), `min` (kurang dari batas minimum), `max` (lebih dari batas
  maksimum), `len` (panjang tidak sesuai — dipakai untuk `code` yang harus
  tepat 6 karakter), `number` (bukan angka — juga dipakai untuk `code`).
- Aplikasi Flutter sebaiknya memetakan setiap kombinasi `field` + aturan ke
  pesan yang ramah pengguna sendiri (jangan menampilkan nama aturan mentah
  seperti `"min"` ke pengguna).

Bila validasi lolos tapi terjadi galat lain (email sudah terdaftar, kode
salah, dll.), bentuknya berbeda: hanya `{"message": "<pesan galat>"}` tanpa
field `validation` — lihat tabel kode error tiap endpoint di atas.

---

## Tiga Jenis Batas Laju (Rate Limit) — Jangan Disamakan

Aplikasi akan menjumpai **tiga jenis batas yang berbeda**, dan pesan yang
ditampilkan ke pengguna sebaiknya berbeda untuk masing-masing, karena
penyebab dan cara mengatasinya berbeda:

### 1. Batas pendaftaran per IP — `POST /register` dan `POST /resend_verify`

- **6 permintaan per menit** dari alamat IP yang sama (dengan sedikit "burst"
  di awal).
- Berlaku untuk `/register` maupun `/resend_verify` — dan keduanya **BUKAN**
  jatah 6/menit terpisah masing-masing. Server mendaftarkan kedua endpoint ini
  dengan **instance limiter yang sama persis**, jadi permintaan ke `/register`
  dan ke `/resend_verify` dari IP yang sama **mengurangi jatah gabungan yang
  sama**: total keduanya digabung tidak boleh lebih dari 6 per menit, bukan
  6 untuk `/register` ditambah 6 lagi untuk `/resend_verify`.
- Kena batas ini biasanya berarti pengguna (atau jaringan yang sama, misalnya
  WiFi kantor/kampus) mencoba berkali-kali dalam waktu singkat.
- **Saran tampilan:** "Terlalu banyak percobaan dalam waktu singkat. Tunggu
  sebentar lalu coba lagi."
- Response `429` dari batas ini **tidak membawa body JSON object berisi
  pesan** — aplikasi tidak bisa mengandalkan `message` dari response untuk
  kasus ini, harus ditangani berdasarkan status code `429` saja.
- **Perhatikan body-nya secara harfiah:** limiter ini membalas dengan body
  literal `null` (empty JSON value), **bukan** body kosong/tanpa isi dan
  **bukan** `{}`. Bila aplikasi memakai parser JSON yang strict atau langsung
  mengasumsikan hasil parse-nya adalah object (misalnya langsung mengakses
  `response['message']` tanpa memeriksa null lebih dulu), ini bisa membuat
  aplikasi crash atau melempar exception saat parsing. Periksa status code
  `429` dahulu sebelum mencoba mem-parsing body sebagai object, dan jangan
  asumsikan body selalu berbentuk object untuk response ini.

### 2. Batas kirim ulang per alamat email — `POST /resend_verify`

- **3 pengiriman kode per jam** untuk **alamat email yang sama**, terlepas
  dari IP mana pun permintaan datang.
- Ini batas yang lebih ketat dan lebih spesifik daripada batas IP di atas —
  tujuannya mencegah satu alamat email dibanjiri email verifikasi.
- Response `429` untuk batas ini **membawa pesan**:
  `"terlalu banyak permintaan kode, coba lagi satu jam lagi"`.
- **Saran tampilan:** "Sudah terlalu sering meminta kode untuk email ini.
  Coba lagi 1 jam lagi." — beri tahu satuan waktunya (jam), berbeda dari batas
  IP yang sifatnya "sebentar".

### 3. Batas percobaan kode — `POST /verify_email`

- **5 kali percobaan kode salah** untuk **kode yang sedang aktif**. Setelah
  percobaan ke-6, kode itu langsung dibatalkan di server (bukan hanya
  diblokir sementara) — pengguna **harus** minta kode baru lewat
  `/resend_verify`, mengetik kode yang sama lagi (walau kebetulan benar)
  tidak akan diterima.
- Ini bukan batas berbasis waktu seperti dua batas di atas, melainkan
  penghitung percobaan per kode.
- Response `429` untuk batas ini membawa pesan:
  `"terlalu banyak percobaan, minta kode baru"`.
- **Saran tampilan:** "Terlalu banyak percobaan salah. Kode ini sudah tidak
  berlaku — minta kode baru." lalu arahkan ke tombol "Kirim ulang kode".

**Ringkasan perbedaan pesan:**

| Batas | Endpoint | Body `429`? | Saran pesan |
|---|---|---|---|
| Per IP | `/register` dan `/resend_verify` (jatah 6/menit gabungan, BUKAN 6 masing-masing) | body literal `null`, bukan object dan bukan kosong | "Terlalu banyak percobaan, tunggu sebentar." |
| Per email/jam | `/resend_verify` | ada (JSON object dengan `message`) | "Terlalu sering minta kode, tunggu 1 jam." |
| Per kode | `/verify_email` | ada (JSON object dengan `message`) | "Kode ini sudah tidak berlaku, minta kode baru." |

---

## Catatan untuk Tim Backend/Reviewer (Ketidaksesuaian yang Ditemukan)

Tidak ditemukan ketidaksesuaian material antara dokumen desain (spec) dan
kode yang berjalan untuk kontrak API yang dikonsumsi Flutter (bentuk request,
field, kode HTTP, pesan galat, nilai limiter semuanya cocok). Ada perbedaan
kecil yang murni internal dan tidak memengaruhi dokumen ini: nama method pada
interface `RegisterRepositories` di spec (`FindUserByEmail`) berbeda dari nama
method sebenarnya di kode (`FindUserForVerify`) — ini detail implementasi,
bukan bagian dari kontrak HTTP.
