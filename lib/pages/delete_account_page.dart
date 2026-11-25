import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/app_links.dart';
import '../core/config/env.dart';
import '../core/theme/app_colors.dart';
import '../widgets/app_top_bar.dart';
import 'delete_account_confirm_page.dart';

/// **Layar A — penjelasan** pada alur Hapus Akun.
///
/// Isinya mengikuti brief backend (29 Sep 2026) dan harus sama dengan halaman
/// web `/hapus-akun`: apa yang dihapus, apa yang tetap disimpan, syaratnya,
/// dan bahwa tindakan ini tidak bisa dibatalkan. Google memeriksa hal ini
/// saat meninjau aplikasi yang punya fitur daftar akun.
///
/// Sengaja dipisah dari layar konfirmasi: pembeli membaca dulu, memutuskan,
/// baru diminta membuktikan dirinya. Menggabungkan keduanya membuat kolom
/// kata sandi terbaca sebagai formulir biasa.
class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key});

  static const String _namaApp = 'Roti Gembung Panglima';

  Future<void> _bukaKebijakan(BuildContext context) async {
    final uri = Uri.tryParse(AppLinks.hapusAkun);
    if (uri == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Tidak bisa membuka halaman.')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka halaman.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Hapus Akun'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Hapus akun $_namaApp?',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 18),

          const _Bagian(
            judul: 'Yang akan dihapus',
            poin: [
              'Nama, email, dan nomor HP Anda',
              'Kata sandi',
              'Keranjang belanja',
              'Identitas notifikasi perangkat ini',
            ],
          ),
          const SizedBox(height: 18),

          _Bagian(
            judul: 'Yang tetap disimpan',
            poin: [
              'Riwayat transaksi dan pembayaran disimpan selama '
                  '${AppPolicy.retensiTransaksi} untuk kewajiban akuntansi '
                  'dan perpajakan, dan tidak lagi dikaitkan dengan identitas '
                  'Anda.',
            ],
          ),
          if (AppPolicy.masihDraf) ...[
            const SizedBox(height: 10),
            const _CatatanDraf(),
          ],
          const SizedBox(height: 18),

          // Syarat keranjang kosong adalah tambahan di sisi aplikasi — tidak
          // ada di brief backend maupun halaman web `/hapus-akun`. Disebut di
          // sini supaya pembeli tidak tertahan pada layar berikutnya oleh
          // aturan yang tak pernah diberitahukan.
          const _KotakPeringatan(
            teks:
                'Akun tidak bisa dihapus selama keranjang masih berisi, atau '
                'masih ada pesanan yang belum diambil atau pembayaran yang '
                'belum selesai. Penghapusan tidak bisa dibatalkan.',
          ),

          if (AppLinks.ada(AppLinks.hapusAkun)) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _bukaKebijakan(context),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Kebijakan hapus akun'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.maroon700,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],

          const SizedBox(height: 26),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DeleteAccountConfirmPage(),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Lanjutkan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: TextStyle(color: AppColors.grey600)),
            ),
          ),

          if (!Env.isAccountDeletionLive) ...[
            const SizedBox(height: 12),
            const CatatanTiruanHapusAkun(),
          ],
        ],
      ),
    );
  }
}

/// Satu blok berjudul dengan daftar poin.
class _Bagian extends StatelessWidget {
  const _Bagian({required this.judul, required this.poin});

  final String judul;
  final List<String> poin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          judul,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        for (final p in poin) _Poin(p),
      ],
    );
  }
}

class _Poin extends StatelessWidget {
  const _Poin(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.grey400,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.grey600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KotakPeringatan extends StatelessWidget {
  const _KotakPeringatan({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Penanda bahwa teks kebijakannya belum final.
///
/// Brief melarang mengambil screenshot final sebelum PRD Q3 & Q5 terjawab.
/// Penanda ini membuat keadaan itu terlihat, bukan tersembunyi di komentar
/// kode — hilang sendiri begitu [AppPolicy.retensiTransaksi] diisi.
class _CatatanDraf extends StatelessWidget {
  const _CatatanDraf();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.yellow50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Teks masa simpan masih menunggu ketetapan. Jangan dipakai untuk '
        'screenshot final Google Play.',
        style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.grey600),
      ),
    );
  }
}

/// Catatan bahwa layanan penghapusan di server belum aktif.
///
/// Tampil sampai `DELETE_ACCOUNT_LIVE=true` di `.env`. Sengaja terlihat oleh
/// siapa pun yang membuka halaman ini — termasuk penguji internal — supaya
/// tidak ada yang mengira datanya benar-benar sudah terhapus di server.
class CatatanTiruanHapusAkun extends StatelessWidget {
  const CatatanTiruanHapusAkun({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.yellow50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.gold500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Uji coba: layanan penghapusan di server belum aktif. Anda akan '
              'dikeluarkan dari aplikasi, tetapi data di server belum terhapus.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppColors.grey600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
