import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/models/order.dart';
import '../data/order_store.dart';
import '../pages/order_status_page.dart';
import '../pages/payment_page.dart';

/// Satu pesanan pada satu waktu.
///
/// Pembeli harus menyelesaikan (atau membatalkan) pesanan yang sedang berjalan
/// sebelum membuat yang baru. Tanpa aturan ini, ia bisa punya dua nomor
/// pesanan sekaligus — membingungkan di konter, dan dua tagihan terbuka di
/// gateway pembayaran.
///
/// Mengembalikan **true bila transaksi baru boleh diteruskan**.
///
/// [refresh] menentukan apakah keadaan diambil ulang dari server lebih dulu.
/// Dinyalakan di titik keputusan besar (checkout), dimatikan untuk tindakan
/// sering seperti menambah barang ke keranjang — di sana permintaan jaringan
/// tiap ketukan membuat tombol terasa berat, sementara [orderStore] sudah
/// disegarkan saat aplikasi dibuka, sesudah pembayaran, saat tab Pesanan
/// dibuka, dan ketika push masuk.
///
/// Bila pemeriksaan gagal (mis. jaringan mati), pembeli **tidak** ditahan —
/// menghalangi orang berbelanja karena sinyal buruk lebih merugikan daripada
/// dua pesanan yang sesekali lolos.
Future<bool> ensureNoOngoingOrder(
  BuildContext context, {
  bool refresh = true,
}) async {
  if (refresh) await orderStore.refresh();
  final order = orderStore.latest;
  if (order == null) return true;
  if (!context.mounted) return false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => _OngoingOrderDialog(order: order),
  );
  return false;
}

class _OngoingOrderDialog extends StatelessWidget {
  const _OngoingOrderDialog({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      // `Center` wajib: slot ikon `AlertDialog` berada di kolom yang meregang
      // selebar dialog, jadi tanpa ini lingkarannya tergambar lonjong.
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
            Icons.receipt_long,
            color: AppColors.maroon700,
            size: 28,
          ),
        ),
      ),
      title: Text(
        order.isAwaitingPayment
            ? 'Pembayaran Belum Selesai'
            : 'Masih Ada Pesanan Berjalan',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            order.isAwaitingPayment
                ? 'Ada pesanan yang belum dibayar. Lunasi dulu pesanan itu '
                      'sebelum memesan lagi.'
                : 'Selesaikan dulu pesanan yang sedang berjalan sebelum '
                      'memesan lagi. Satu pesanan diproses pada satu waktu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.grey600,
            ),
          ),
          if (order.documentNumber.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.creamSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    'Nomor pesanan',
                    style: TextStyle(fontSize: 11, color: AppColors.grey600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.documentNumber,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.maroon700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Belum dibayar → antar ke pembayarannya, bukan ke halaman
              // status: pesanan POS-nya belum terbentuk sehingga belum ada
              // id numerik untuk dimuat.
              if (order.isAwaitingPayment) {
                openResumePayment(context, order);
                return;
              }
              // Selain itu, hanya dibuka bila detailnya memang bisa dimuat —
              // jangan mengantar pembeli ke halaman kosong.
              if (!order.isUsable) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderStatusPage(
                    orderId: order.id,
                    initialOrder: order,
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.maroon700,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              order.isAwaitingPayment
                  ? 'Lanjutkan Pembayaran'
                  : order.isUsable
                  ? 'Lihat Pesanan'
                  : 'Mengerti',
            ),
          ),
        ),
        if (order.isUsable || order.isAwaitingPayment)
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
