import 'package:flutter/material.dart';

import '../core/network/api_error.dart';
import '../core/theme/app_colors.dart';
import '../data/models/order.dart';
import '../pages/order_detail_page.dart';
import 'order_card.dart';

/// Pemuat sehalaman pesanan (mis. `orderRepository.active`).
typedef OrderPageLoader = Future<OrderPage> Function(int page);

/// Daftar pesanan berhalaman dengan tarik-untuk-refresh, tombol muat lebih
/// banyak, serta keadaan kosong/galat. Dipakai tab Pesanan & Riwayat.
class OrderListView extends StatefulWidget {
  const OrderListView({
    super.key,
    required this.load,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.emptyEmoji = '🧺',
    this.emptyAction,
  });

  final OrderPageLoader load;
  final String emptyTitle;
  final String emptySubtitle;
  final String emptyEmoji;

  /// Tombol opsional pada keadaan kosong (mis. "Lihat Menu").
  final Widget? emptyAction;

  @override
  State<OrderListView> createState() => _OrderListViewState();
}

class _OrderListViewState extends State<OrderListView> {
  final List<Order> _orders = [];

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.load(1);
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(result.orders);
        _page = result.page;
        _hasMore = result.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, fallback: 'Gagal memuat pesanan.');
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await widget.load(_page + 1);
      if (!mounted) return;
      setState(() {
        _orders.addAll(result.orders);
        _page = result.page;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  /// Buka detail; muat ulang daftar bila pesanan berubah di sana (dibatalkan).
  Future<void> _openDetail(Order order) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: order.id)),
    );
    if (changed == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.maroon700),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.maroon700,
      child: _error != null
          ? _MessageView(
              emoji: '⚠️',
              title: 'Gagal memuat pesanan',
              subtitle: _error!,
              action: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            )
          : _orders.isEmpty
          ? _MessageView(
              emoji: widget.emptyEmoji,
              title: widget.emptyTitle,
              subtitle: widget.emptySubtitle,
              action: widget.emptyAction,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _orders.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i >= _orders.length) {
                  return Center(
                    child: _loadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              color: AppColors.maroon700,
                            ),
                          )
                        : TextButton(
                            onPressed: _loadMore,
                            child: const Text('Muat lebih banyak'),
                          ),
                  );
                }
                final order = _orders[i];
                return OrderCard(
                  order: order,
                  onTap: () => _openDetail(order),
                );
              },
            ),
    );
  }
}

/// Keadaan kosong / galat — tetap bisa ditarik untuk refresh.
class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      children: [
        Text(emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.grey600),
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          Center(child: action),
        ],
      ],
    );
  }
}
