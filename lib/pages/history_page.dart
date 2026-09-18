import 'package:flutter/material.dart';

import '../data/models/order.dart';
import '../data/order_repository.dart';
import '../widgets/order_list.dart';

/// Halaman Riwayat — pesanan yang sudah selesai atau dibatalkan
/// (`status=history`).
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const OrderListView(
      load: _loadHistory,
      emptyEmoji: '🧾',
      emptyTitle: 'Belum ada riwayat pesanan',
      emptySubtitle:
          'Pesanan yang sudah diambil atau dibatalkan akan tercatat di sini.',
    );
  }
}

Future<OrderPage> _loadHistory(int page) =>
    orderRepository.history(page: page);
