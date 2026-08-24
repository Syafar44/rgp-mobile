import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/dummy/dummy_data.dart';
import '../data/notifiers.dart';
import '../widgets/order_card.dart';

/// Halaman Pesanan — daftar pesanan yang masih berjalan.
class PesananPage extends StatelessWidget {
  const PesananPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = DummyData.activeOrders;

    if (orders.isEmpty) {
      return _EmptyPesanan();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => OrderCard(order: orders[i]),
    );
  }
}

class _EmptyPesanan extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🧺', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          const Text(
            'Belum ada pesanan aktif',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Pesanan baru akan muncul di sini.',
            style: TextStyle(color: AppColors.grey600),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => selectedPageNotifier.value = 1,
            icon: const Icon(Icons.bakery_dining_outlined),
            label: const Text('Lihat Menu'),
          ),
        ],
      ),
    );
  }
}
