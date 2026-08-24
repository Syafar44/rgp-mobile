import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/dummy/dummy_data.dart';
import '../widgets/order_card.dart';

/// Halaman History — pesanan yang sudah selesai / dibatalkan.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = DummyData.historyOrders;

    if (orders.isEmpty) {
      return Center(
        child: Text(
          'Belum ada riwayat pesanan.',
          style: TextStyle(color: AppColors.grey600),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => Future<void>.delayed(const Duration(milliseconds: 800)),
      color: AppColors.maroon700,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          for (final order in orders) ...[
            OrderCard(order: order),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
