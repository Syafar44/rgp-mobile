import 'package:flutter/material.dart';

import '../data/notifiers.dart';
import '../data/order_repository.dart';
import '../data/order_store.dart';
import '../widgets/order_list.dart';

/// Halaman Pesanan — pesanan yang masih berjalan (`status=active`,
/// yaitu `app_pending`: sudah checkout, belum diambil & dibayar di outlet).
class PesananPage extends StatelessWidget {
  const PesananPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OrderListView(
      load: (page) async {
        final result = await orderRepository.active(page: page);
        // Halaman pertama = potret terbaru pesanan berjalan; pakai sekalian
        // untuk bilah di atas navbar.
        if (page == 1) orderStore.setActive(result.orders);
        return result;
      },
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
