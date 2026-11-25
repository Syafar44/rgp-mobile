import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../widgets/app_top_bar.dart';
import 'history_page.dart';
import 'pesanan_page.dart';

/// Isi tab pesanan: **Berjalan** (`status=active`) dan **Riwayat**
/// (`status=history`), mengikuti pemisahan yang dipakai server.
///
/// Dipakai dua tempat — sebagai tab di kerangka utama dan sebagai halaman
/// tersendiri lewat [OrdersPage] — jadi tampilannya selalu sama.
class OrdersTabs extends StatelessWidget {
  const OrdersTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: AppColors.maroon700,
            unselectedLabelColor: AppColors.grey600,
            indicatorColor: AppColors.maroon700,
            tabs: [
              Tab(text: 'Berjalan'),
              Tab(text: 'Riwayat'),
            ],
          ),
          const Expanded(
            child: TabBarView(children: [PesananPage(), HistoryPage()]),
          ),
        ],
      ),
    );
  }
}

/// Halaman Pesanan yang dibuka lewat menu (mis. dari Profile).
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppTopBar(title: 'Pesanan Saya'),
      body: OrdersTabs(),
    );
  }
}
