import 'package:flutter/material.dart';

import '../data/notifiers.dart';
import '../data/order_repository.dart';
import '../widgets/order_list.dart';

/// Halaman Pesanan — pesanan yang masih berjalan (`status=active`,
/// yaitu `app_pending`: sudah checkout, belum diambil & dibayar di outlet).
class PesananPage extends StatelessWidget {
  const PesananPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OrderListView(
      load: (page) => orderRepository.active(page: page),
      emptyTitle: 'Belum ada pesanan aktif',
      emptySubtitle: 'Pesanan yang menunggu diambil akan muncul di sini.',
      emptyAction: FilledButton.icon(
        onPressed: () => selectedPageNotifier.value = 1,
        icon: const Icon(Icons.bakery_dining_outlined),
        label: const Text('Lihat Menu'),
      ),
    );
  }
}
