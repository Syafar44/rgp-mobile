import 'package:flutter/material.dart';

import '../core/network/network_probe.dart';
import '../core/theme/app_colors.dart';

/// Lama menunggu sebelum aplikasi menunjukkan bahwa ia sedang memeriksa.
///
/// Jaringan sehat menjawab dalam ~100–250 ms. Memunculkan dialog untuk itu
/// berarti kotak yang muncul lalu lenyap dalam sekejap — terbaca sebagai
/// kedipan atau kerusakan, tepat pada layar yang paling menegangkan bagi
/// pembeli. Di bawah ambang ini, pemeriksaan berjalan tanpa terlihat.
const Duration _ambangTampil = Duration(milliseconds: 450);

/// Pastikan jaringan cukup baik sebelum melanjutkan transaksi.
///
/// Mengembalikan **true bila boleh lanjut**. Tiga kemungkinan:
/// - cepat & baik → tidak ada apa pun di layar, alurnya langsung lanjut;
/// - lambat menjawab → muncul penanda "Memeriksa jaringan";
/// - lambat atau putus → keterangan beserta tombol "Coba Lagi", alur ditahan.
///
/// Ditahan, bukan sekadar diperingatkan: checkout yang terkirim tapi
/// responsnya tidak sampai menghasilkan pesanan ganda dengan dua tagihan —
/// merugikan pembeli dan merepotkan outlet.
Future<bool> ensureNetworkReady(BuildContext context) async {
  final pemeriksaan = networkProbe.check();

  // Balapan: siapa pun yang lebih dulu selesai menentukan apakah pembeli
  // perlu melihat sesuatu.
  NetworkQuality? cepat;
  await Future.any<void>([
    pemeriksaan.then((v) => cepat = v),
    Future<void>.delayed(_ambangTampil),
  ]);

  // Selesai sebelum ambang & jaringannya baik → jangan tampilkan apa pun.
  if (cepat != null && cepat!.bolehTransaksi) return true;
  if (!context.mounted) return false;

  final hasil = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _NetworkCheckDialog(
      pemeriksaan: cepat == null ? pemeriksaan : null,
      hasilAwal: cepat,
    ),
  );
  return hasil ?? false;
}

class _NetworkCheckDialog extends StatefulWidget {
  const _NetworkCheckDialog({this.pemeriksaan, this.hasilAwal});

  /// Pemeriksaan yang masih berjalan saat dialog dibuka. Null bila hasilnya
  /// sudah diketahui — lihat [hasilAwal].
  final Future<NetworkQuality>? pemeriksaan;

  /// Hasil yang sudah ada sebelum dialog muncul (pemeriksaan cepat tapi
  /// gagal), supaya tidak diperiksa dua kali.
  final NetworkQuality? hasilAwal;

  @override
  State<_NetworkCheckDialog> createState() => _NetworkCheckDialogState();
}

class _NetworkCheckDialogState extends State<_NetworkCheckDialog> {
  NetworkQuality? _hasil;

  @override
  void initState() {
    super.initState();
    _hasil = widget.hasilAwal;
    final berjalan = widget.pemeriksaan;
    if (berjalan != null) _tunggu(berjalan);
  }

  Future<void> _tunggu(Future<NetworkQuality> pemeriksaan) async {
    final hasil = await pemeriksaan;
    if (!mounted) return;
    // Jaringan baik → jangan tahan pembeli sedetik pun lebih lama.
    if (hasil.bolehTransaksi) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _hasil = hasil);
  }

  Future<void> _cobaLagi() async {
    setState(() => _hasil = null);
    await _tunggu(networkProbe.check());
  }

  @override
  Widget build(BuildContext context) {
    final hasil = _hasil;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: _ikon(hasil),
      title: Text(
        hasil == null
            ? 'Memeriksa Jaringan'
            : hasil == NetworkQuality.putus
            ? 'Tidak Ada Koneksi'
            : 'Jaringan Tidak Stabil',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: Text(
        switch (hasil) {
          null => 'Sebentar, memastikan pesanan Anda bisa terkirim dengan '
              'aman.',
          NetworkQuality.putus =>
            'Aplikasi tidak bisa menghubungi server. Periksa koneksi Anda '
                'lalu coba lagi.',
          _ => 'Koneksi Anda sedang lambat. Pesanan ditahan dulu agar tidak '
              'terkirim dua kali dan tertagih dua kali.',
        },
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.grey600),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: hasil == null
          // Selama memeriksa tidak ada tombol apa pun: menawarkan "Batal"
          // pada tunggu yang paling lama enam detik hanya mengundang
          // pembeli membatalkan pesanannya sendiri.
          ? const [SizedBox.shrink()]
          : [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _cobaLagi,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Coba Lagi'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.maroon700,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Batal',
                    style: TextStyle(color: AppColors.grey600),
                  ),
                ),
              ),
            ],
    );
  }

  /// Ikon bulat di kepala dialog.
  ///
  /// Dibungkus [Center]: `AlertDialog` menaruh slot ikonnya di dalam kolom
  /// yang meregang selebar dialog, sehingga `Container` berukuran tetap pun
  /// ikut melar — lingkaran jadi lonjong dan `CircularProgressIndicator`
  /// tergambar sebagai garis melengkung panjang.
  Widget _ikon(NetworkQuality? hasil) {
    final memeriksa = hasil == null;
    return Center(
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: memeriksa
              ? AppColors.maroon700.withValues(alpha: 0.08)
              : AppColors.warning.withValues(alpha: 0.12),
        ),
        child: memeriksa
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.maroon700,
                ),
              )
            : Icon(
                hasil == NetworkQuality.putus
                    ? Icons.wifi_off
                    : Icons.network_check,
                color: AppColors.warning,
                size: 28,
              ),
      ),
    );
  }
}
