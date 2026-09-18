import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatter.dart';
import '../core/utils/wita.dart';
import '../data/models/order.dart';

/// Warna badge untuk tiap status pesanan (memakai warna status brand).
Color orderStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.appPending:
      return AppColors.warning;
    case OrderStatus.active:
      return AppColors.success;
    case OrderStatus.appCancelled:
    case OrderStatus.voided:
      return AppColors.error;
    case OrderStatus.unknown:
      return AppColors.grey600;
  }
}

/// Kartu ringkasan satu pesanan. Dipakai di halaman Pesanan & Riwayat.
///
/// Sumbernya respons daftar pesanan yang tidak membawa rincian item, jadi kartu
/// ini menampilkan ringkasan saja — rincian ada di halaman detail.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.onTap});

  final Order order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(order.status);
    return Material(
      color: AppColors.creamSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.grey100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nomor inilah yang disebut pembeli ke kasir.
                        Text(
                          order.documentNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.outletName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      // Label dari server; enum hanya untuk logika.
                      order.statusLabel.isEmpty
                          ? order.status.code
                          : order.statusLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: 14,
                    color: AppColors.grey400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${order.itemCount} item',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.grey600,
                    ),
                  ),
                  if (order.pickupAt != null) ...[
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.schedule,
                      size: 14,
                      color: AppColors.grey400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ambil ${formatJamWita(order.pickupAt!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grey600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    formatRupiah(order.totalAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.maroon700,
                    ),
                  ),
                ],
              ),
              if (order.createdAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Dipesan ${formatTanggal(order.createdAt!)} WITA',
                  style: const TextStyle(fontSize: 11, color: AppColors.grey400),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
