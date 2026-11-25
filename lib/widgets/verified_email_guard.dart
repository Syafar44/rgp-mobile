import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/auth_store.dart';
import '../data/cart_store.dart';
import '../data/models/cart.dart';
import '../data/order_store.dart';

/// Pastikan email pembeli sudah diverifikasi sebelum bertransaksi.
///
/// Mengembalikan **true bila boleh lanjut**.
///
/// Menjelajah menu, melihat harga, dan mengisi keranjang tetap bebas — yang
/// ditahan hanya langkah yang menghasilkan pesanan & tagihan. Email adalah
/// satu-satunya cara menghubungi pembeli bila pesanannya bermasalah, jadi
/// pesanan dari alamat yang belum terbukti hidup menyulitkan semua pihak.
Future<bool> ensureEmailVerified(BuildContext context) async {
  if (authStore.isEmailVerified) return true;

  final keluar = await showDialog<bool>(
    context: context,
    builder: (ctx) => const _VerifikasiDialog(),
  );
  if (keluar != true || !context.mounted) return false;

  // Verifikasi butuh kata sandi (untuk mengambil token baru sesudahnya), dan
  // sesi yang sedang berjalan tidak menyimpannya. Jalan yang tersedia:
  // keluar, lalu masuk lagi — layar masuk mengenali email yang belum
  // terverifikasi dan langsung mengantar ke layar kode.
  cartStore.cart.value = ServerCart.empty();
  orderStore.clear();
  authStore.logout();
  return false;
}

class _VerifikasiDialog extends StatelessWidget {
  const _VerifikasiDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Center(
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.maroon50,
          ),
          child: const Icon(
            Icons.mark_email_unread_outlined,
            color: AppColors.maroon700,
            size: 28,
          ),
        ),
      ),
      title: const Text(
        'Verifikasi Email Dulu',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pesanan hanya bisa dibuat dari akun dengan email yang sudah '
            'diverifikasi — itu satu-satunya cara kami menghubungi Anda bila '
            'ada masalah dengan pesanannya.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.grey600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.creamSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              authStore.currentUser.value?.email ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.maroon700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Anda akan dikeluarkan sebentar. Masuk lagi dengan akun yang sama, '
            'dan kode verifikasi langsung dikirim.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.grey600),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.maroon700,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Verifikasi Sekarang'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Nanti Saja',
              style: TextStyle(color: AppColors.grey600),
            ),
          ),
        ),
      ],
    );
  }
}
