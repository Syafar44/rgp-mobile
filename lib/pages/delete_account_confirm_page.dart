import 'package:flutter/material.dart';

import '../core/network/api_error.dart';
import '../core/network/network_probe.dart';
import '../core/push/push_service.dart';
import '../core/theme/app_colors.dart';
import '../data/auth_store.dart';
import '../data/cart_store.dart';
import '../data/customer_repository.dart';
import '../data/models/cart.dart';
import '../data/notifiers.dart';
import '../data/order_store.dart';
import '../data/outlet_store.dart';
import '../widgets/app_top_bar.dart';
import 'auth/auth_widgets.dart';

/// **Layar B — konfirmasi** pada alur Hapus Akun.
///
/// Pembeli aplikasi ini masuk dengan email & kata sandi, jadi konfirmasinya
/// berupa kata sandi (brief backend §1.B). Penghapusan tidak bisa dibatalkan,
/// dan HP yang tertinggal dalam keadaan masuk adalah kejadian biasa.
///
/// Bila server menjawab `409 active_orders_exist`, layar ini berganti menjadi
/// **layar C** — bukan menampilkan pesan galat biasa, karena yang dibutuhkan
/// pembeli adalah jalan ke daftar pesanannya.
class DeleteAccountConfirmPage extends StatefulWidget {
  const DeleteAccountConfirmPage({super.key});

  @override
  State<DeleteAccountConfirmPage> createState() =>
      _DeleteAccountConfirmPageState();
}

/// Alasan penghapusan tertahan.
enum _Tertahan {
  /// `409 active_orders_exist` dari server.
  pesananAktif,

  /// Keranjang masih berisi. Diperiksa di sisi aplikasi — server tidak
  /// menghitungnya sebagai penghalang.
  keranjangBerisi,
}

class _DeleteAccountConfirmPageState extends State<DeleteAccountConfirmPage> {
  final _password = TextEditingController();

  bool _obscure = true;
  bool _deleting = false;
  _Tertahan? _tertahan;

  /// Pesan kegagalan yang bukan salah pembeli (503, 500, jaringan).
  String? _gagalUmum;

  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));

    // Keranjang berisi ikut menahan penghapusan. Diperiksa begitu layar ini
    // dibuka, bukan setelah kata sandi diketik — menolak orang setelah ia
    // repot mengetik adalah pemborosan yang bisa dihindari.
    if (cartStore.cart.value.items.isNotEmpty) {
      _tertahan = _Tertahan.keranjangBerisi;
    }
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  /// Tombol baru aktif setelah kolomnya terisi, dan mati selama permintaan
  /// berjalan — mencegah ketukan ganda pada tindakan yang tidak bisa
  /// dibatalkan.
  bool get _canDelete => !_deleting && _password.text.isNotEmpty;

  Future<void> _delete() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _deleting = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      // Jaringan diperiksa lebih dulu. Penghapusan akun adalah tindakan yang
      // tidak bisa dibatalkan: pembeli harus tahu apakah permintaannya
      // benar-benar sampai, bukan menebak dari layar yang diam.
      if (!(await networkProbe.check()).bolehTransaksi) {
        if (!mounted) return;
        setState(() {
          _deleting = false;
          _gagalUmum =
              'Tidak ada koneksi ke server. Periksa jaringan Anda lalu coba '
              'lagi.';
        });
        return;
      }

      await customerRepository.deleteAccount(password: _password.text);
      if (!mounted) return;
      await _bersihkanDanKeluar();
    } on ApiException catch (e) {
      if (!mounted) return;
      // 409: pesanan masih berjalan → pindah ke layar C.
      if (e.statusCode == 409) {
        setState(() {
          _deleting = false;
          _tertahan = _Tertahan.pesananAktif;
        });
        return;
      }
      // Kata sandi salah tetap di layar B, menempel di kolomnya (brief §2).
      // Sisanya — layanan sibuk, galat server, jaringan — adalah kegagalan
      // yang tidak bisa diperbaiki pembeli dengan mengetik ulang, jadi
      // tampilannya sendiri lengkap dengan tombol coba lagi.
      setState(() {
        _deleting = false;
        if (e.statusCode == 400) {
          _error = e.message;
          _fieldErrors = e.validation.map((k, v) => MapEntry(k, v.toString()));
        } else {
          _gagalUmum = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _gagalUmum = apiErrorMessage(
          e,
          fallback: 'Gagal menghapus akun. Coba lagi.',
        );
      });
    }
  }

  /// Ulangi penghapusan dengan kata sandi yang sudah diketik.
  void _cobaLagi() {
    setState(() => _gagalUmum = null);
    _delete();
  }

  /// **Layar D** — bersihkan seluruh jejak akun di perangkat, lalu pulang ke
  /// layar masuk.
  ///
  /// Bukan hanya token: keranjang, pesanan berjalan, dan outlet terakhir ikut
  /// dibuang supaya tidak ada sisa akun yang sudah tiada menyeberang ke
  /// pengguna berikutnya di HP yang sama.
  Future<void> _bersihkanDanKeluar() async {
    // Lepas perangkat dari OneSignal lebih dulu, selagi identitasnya masih
    // diketahui — tanpa ini push pesanan akun lama bisa tetap mendarat di
    // sini. `authStore.logout()` juga memicunya lewat listener di `main.dart`;
    // dipanggil di sini agar urutannya pasti dan tidak bergantung listener.
    await pushService.unlink();

    cartStore.cart.value = ServerCart.empty();
    orderStore.clear();
    outletStore.clear();
    authStore.logout();

    if (!mounted) return;
    // `_AuthGate` menampilkan layar masuk begitu `currentUser` menjadi null;
    // seluruh tumpukan halaman dibuang agar tombol kembali tidak bisa
    // mengembalikan pembeli ke halaman akun yang sudah dihapus.
    Navigator.of(context).popUntil((r) => r.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Akun Anda sudah dihapus.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _lihatPesanan() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    selectedPageNotifier.value = ordersTabIndex;
  }

  /// Kembali ke halaman utama; bilah keranjang di bawah layar langsung
  /// mengantar pembeli ke isinya.
  void _lihatKeranjang() =>
      Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final tertahan = _tertahan;
    final gagal = _gagalUmum;
    return Scaffold(
      appBar: const AppTopBar(title: 'Hapus Akun'),
      body: switch ((tertahan, gagal)) {
        (final _Tertahan t, _) => _TertahanView(
          alasan: t,
          onLanjut: t == _Tertahan.pesananAktif
              ? _lihatPesanan
              : _lihatKeranjang,
        ),
        (_, final String pesan) => _GagalUmumView(
          pesan: pesan,
          onCobaLagi: _cobaLagi,
        ),
        _ => _formulir(),
      },
    );
  }

  Widget _formulir() {
    return AbsorbPointer(
      absorbing: _deleting,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AuthErrorBox(message: _error),
          const Text(
            'Masukkan kata sandi Anda',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Diminta untuk memastikan yang menghapus benar-benar pemilik akun.',
            style: TextStyle(fontSize: 13, color: AppColors.grey600),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofocus: true,
            decoration: authInputDecoration(
              label: 'Kata Sandi *',
              hint: 'Kata sandi akun Anda',
              errorText: _fieldErrors['password'],
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.grey400,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _canDelete ? _delete : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                disabledBackgroundColor: AppColors.grey300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _deleting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.white,
                      ),
                    )
                  : const Text(
                      'Hapus Akun',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: _deleting ? null : () => Navigator.pop(context),
              child: Text('Batal', style: TextStyle(color: AppColors.grey600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// **Layar C** — penghapusan tertahan.
///
/// Dua sebabnya berbeda asal: pesanan berjalan datang dari server (`409`),
/// keranjang berisi diperiksa aplikasi. Tampilannya disatukan supaya pembeli
/// selalu menemui bentuk yang sama — yang berubah hanya keterangan dan ke
/// mana tombolnya mengantar.
class _TertahanView extends StatelessWidget {
  const _TertahanView({required this.alasan, required this.onLanjut});

  final _Tertahan alasan;
  final VoidCallback onLanjut;

  bool get _pesanan => alasan == _Tertahan.pesananAktif;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.maroon50,
              ),
              child: Icon(
                _pesanan ? Icons.receipt_long : Icons.shopping_cart_outlined,
                size: 40,
                color: AppColors.maroon700,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Akun Belum Bisa Dihapus',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _pesanan
                  ? 'Masih ada pesanan yang belum diambil atau pembayaran '
                        'yang belum selesai. Selesaikan pesanan tersebut lalu '
                        'coba lagi.'
                  : 'Keranjang Anda masih berisi. Selesaikan atau kosongkan '
                        'keranjang lebih dulu, lalu coba lagi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.grey600,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onLanjut,
                icon: const Icon(Icons.arrow_forward, size: 20),
                label: Text(_pesanan ? 'Lihat Pesanan' : 'Lihat Keranjang'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon700,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kegagalan yang bukan salah pembeli: layanan sibuk (`503`), galat server
/// (`500`), atau jaringan putus.
///
/// Dibuat sebagai layar penuh, bukan pesan kecil di atas formulir: mengetik
/// ulang kata sandi tidak akan memperbaikinya, jadi yang perlu ditawarkan
/// adalah mencoba lagi — bukan mengisi ulang.
class _GagalUmumView extends StatelessWidget {
  const _GagalUmumView({required this.pesan, required this.onCobaLagi});

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.warning.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Penghapusan Gagal',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pesan,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.grey600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Akun Anda belum dihapus.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCobaLagi,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Coba Lagi'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon700,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Kembali',
                  style: TextStyle(color: AppColors.grey600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
