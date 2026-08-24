import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatter.dart';
import '../data/models/order.dart';

/// Warna badge untuk tiap status pesanan (memakai warna status brand).
Color orderStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return AppColors.warning;
    case OrderStatus.diproses:
      return AppColors.info;
    case OrderStatus.selesai:
      return AppColors.success;
    case OrderStatus.dibatalkan:
      return AppColors.error;
  }
}

/// Kartu ringkasan satu pesanan. Dipakai di halaman Pesanan & History.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(order.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.creamSurface,
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
                    Text(
                      order.id,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.customer,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              // Pesanan yang sudah tuntas tak bisa dibatalkan (sudah dibayar),
              // jadi tampilkan aksi "Beli Lagi" alih-alih tag status.
              if (order.status.isDone)
                _BeliLagiButton(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${order.id} ditambahkan ke keranjang'),
                      duration: const Duration(seconds: 1),
                    ),
                  ),
                )
              else
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
                    order.status.label,
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
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.product.name} × ${item.qty}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Text(
                    formatRupiah(item.subtotal),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 14,
                color: AppColors.grey400,
              ),
              const SizedBox(width: 4),
              Text(
                formatTanggal(order.createdAt),
                style: const TextStyle(fontSize: 12, color: AppColors.grey600),
              ),
              const Spacer(),
              const Text(
                'Total  ',
                style: TextStyle(fontSize: 12, color: AppColors.grey600),
              ),
              Text(
                formatRupiah(order.total),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.maroon700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tombol "Beli Lagi" untuk memesan ulang pesanan yang sudah tuntas.
class _BeliLagiButton extends StatelessWidget {
  const _BeliLagiButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.maroon700),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.replay, size: 15, color: AppColors.maroon700),
              SizedBox(width: 4),
              Text(
                'Beli Lagi',
                style: TextStyle(
                  color: AppColors.maroon700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
