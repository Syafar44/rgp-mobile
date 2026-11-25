import 'package:flutter/material.dart';

import '../core/config/app_features.dart';
import '../core/theme/app_colors.dart';
import '../data/item_swap_store.dart';
import '../data/models/order.dart';
import '../data/order_store.dart';
import '../pages/order_status_page.dart';
import '../pages/payment_page.dart';

/// Bilah pesanan berjalan, tampil tepat di atas bilah keranjang selama ada
/// pesanan yang belum diambil. Menekannya membuka halaman status pesanan.
///
/// Sengaja dibedakan warnanya dari [CartBar] (krem, bukan maroon) supaya tidak
/// tertukar saat keduanya muncul bersamaan — keranjang berisi menu yang belum
/// dipesan, bilah ini pesanan yang sudah dibayar.
class ActiveOrderBar extends StatelessWidget {
  const ActiveOrderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Order>>(
      valueListenable: orderStore.active,
      builder: (context, orders, _) {
        if (orders.isEmpty) return const SizedBox.shrink();
        // Yang butuh tindakan pembeli didahulukan — belum dibayar, lalu item
        // habis yang menunggu pengganti — sedangkan pesanan yang sedang
        // disiapkan hanya perlu ditunggu.
        final order = orders.firstWhere(
          (o) => o.isAwaitingPayment,
          orElse: () => orders.firstWhere(
            (o) => o.status.needsAction,
            orElse: () => orders.first,
          ),
        );
        final lainnya = orders.length - 1;
        final belumBayar = order.isAwaitingPayment;
        // TODO(ganti-item): hapus gate saat modul dirilis
        final perluTindakan = kFiturGantiItem && order.status.needsAction;
        final habis = perluTindakan
            ? itemSwapStore.of(order.id)?.belumSelesai ?? 0
            : 0;
        // Item habis memakai warna peringatan, bukan maroon: pesanannya sudah
        // dibayar, tetapi tidak akan disiapkan sebelum pembeli memilih.
        final aksen = perluTindakan ? AppColors.warning : AppColors.maroon700;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Material(
            color: perluTindakan ? AppColors.warningBg : AppColors.creamSurface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () async {
                // Belum dibayar → langsung ke halaman pembayaran. Pesanan ini
                // belum punya id numerik, jadi halaman status memang tidak
                // bisa memuatnya.
                if (belumBayar) {
                  await openResumePayment(context, order);
                  return;
                }
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderStatusPage(
                      orderId: order.id,
                      initialOrder: order,
                    ),
                  ),
                );
                // Status bisa berubah di sana (mis. dibatalkan) — segarkan
                // supaya bilahnya ikut hilang bila sudah tidak berjalan.
                await orderStore.refresh();
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: aksen, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: aksen,
                      ),
                      child: Icon(
                        belumBayar
                            ? Icons.payments_outlined
                            : perluTindakan
                            ? Icons.report_problem_outlined
                            : Icons.sync,
                        size: 18,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            belumBayar
                                ? 'Lanjutkan pembayaran'
                                : perluTindakan
                                ? 'Perlu tindakan'
                                : lainnya > 0
                                ? 'Pesanan sedang diproses (+$lainnya lagi)'
                                : 'Pesanan sedang diproses',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            perluTindakan && habis > 0
                                ? '$habis item tidak tersedia · '
                                      '${order.documentNumber}'
                                : order.documentNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.grey600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      belumBayar
                          ? 'Bayar'
                          : perluTindakan
                          ? 'Pilih'
                          : 'Lihat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: aksen,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: aksen),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
