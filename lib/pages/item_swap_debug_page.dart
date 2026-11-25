import 'package:flutter/material.dart';

import '../core/network/api_error.dart';
import '../core/theme/app_colors.dart';
import '../data/item_swap_repository.dart';
import '../data/item_swap_store.dart';
import '../data/models/item_swap.dart';
import '../data/models/order.dart';
import '../data/order_store.dart';
import '../data/outlet_store.dart';
import 'order_status_page.dart';

/// Simulasi Item Habis — **hanya build debug** (dibuka dari Profile, di blok
/// `AppLog.enabled`).
///
/// Server belum bisa menandai item habis, jadi di sinilah keadaan itu
/// dipicu: pilih pesanan berjalan yang sudah dibayar (atau buat pesanan
/// tiruan berisi 3 item), tandai 1–2 itemnya habis, lalu statusnya menjadi
/// "Perlu tindakan".
class ItemSwapDebugPage extends StatefulWidget {
  const ItemSwapDebugPage({super.key});

  @override
  State<ItemSwapDebugPage> createState() => _ItemSwapDebugPageState();
}

class _ItemSwapDebugPageState extends State<ItemSwapDebugPage> {
  /// Id pesanan asli sasaran; null = pesanan tiruan baru.
  int? _target;
  int _jumlah = 1;
  bool _acak = false;
  bool _busy = false;

  /// Pesanan asli yang boleh disimulasikan: sudah dibayar dan belum punya
  /// simulasi.
  List<Order> get _kandidat => [
    for (final o in orderStore.active.value)
      if (o.status.isPaid && itemSwapStore.of(o.id) == null) o,
  ];

  @override
  void initState() {
    super.initState();
    orderStore.refresh();
  }

  Future<void> _jalankan() async {
    if (_busy) return;
    final target = _kandidat.where((o) => o.id == _target).firstOrNull;
    setState(() => _busy = true);
    try {
      final order = await itemSwapRepository.simulasikan(
        target: target,
        outlet: outletStore.selected.value,
        jumlah: _jumlah,
        acak: _acak,
      );
      if (!mounted) return;
      final habis = order.lines.where((l) => l.tidakTersedia).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${order.documentNumber}: $habis item ditandai habis. '
            'Lihat bilah pesanan di atas navigasi.',
          ),
        ),
      );
      // Kembali ke aplikasi supaya bilah "Perlu tindakan" langsung terlihat.
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamSurface,
      appBar: AppBar(
        backgroundColor: AppColors.creamSurface,
        surfaceTintColor: AppColors.creamSurface,
        title: const Text('Simulasi Item Habis'),
      ),
      body: ValueListenableBuilder<Map<int, OrderSwap>>(
        valueListenable: itemSwapStore.state,
        builder: (context, swaps, _) => ValueListenableBuilder<List<Order>>(
          valueListenable: orderStore.active,
          builder: (context, _, _) => _isi(swaps),
        ),
      ),
    );
  }

  Widget _isi(Map<int, OrderSwap> swaps) {
    final kandidat = _kandidat;
    if (_target != null && !kandidat.any((o) => o.id == _target)) {
      _target = null;
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _judul('Pesanan sasaran'),
        _Kotak(
          children: [
            for (final o in kandidat)
              _pilihan(
                id: o.id,
                title: o.documentNumber,
                subtitle: '${o.outletName} · ${o.statusLabel}',
              ),
            _pilihan(
              id: null,
              title: 'Pesanan tiruan baru (3 item)',
              subtitle:
                  'Outlet: ${outletStore.selected.value?.name ?? '— (katalog '
                      'cadangan)'}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _judul('Item yang habis'),
        _Kotak(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final n in const [1, 2])
                    ChoiceChip(
                      label: Text('$n item'),
                      selected: _jumlah == n,
                      onSelected: (_) => setState(() => _jumlah = n),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              value: _acak,
              onChanged: (v) => setState(() => _acak = v),
              activeThumbColor: AppColors.maroon700,
              title: const Text('Pilih item secara acak'),
              subtitle: const Text('Mati = item dari urutan teratas'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _busy ? null : _jalankan,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow),
            label: const Text('Jalankan Simulasi'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.maroon700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _judul('Simulasi tersimpan'),
        if (swaps.isEmpty)
          Text(
            'Belum ada.',
            style: TextStyle(fontSize: 13, color: AppColors.grey600),
          )
        else
          for (final s in swaps.values) ...[
            _SimulasiTile(swap: s),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _pilihan({
    required int? id,
    required String title,
    required String subtitle,
  }) {
    final dipilih = _target == id;
    return ListTile(
      onTap: () => setState(() => _target = id),
      leading: Icon(
        dipilih ? Icons.radio_button_checked : Icons.radio_button_off,
        color: dipilih ? AppColors.maroon700 : AppColors.grey400,
      ),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _judul(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.grey600,
      ),
    ),
  );
}

class _Kotak extends StatelessWidget {
  const _Kotak({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Column(children: children),
    );
  }
}

/// Satu simulasi yang tersimpan, dengan aksi buka / serahkan / hapus.
class _SimulasiTile extends StatelessWidget {
  const _SimulasiTile({required this.swap});

  final OrderSwap swap;

  @override
  Widget build(BuildContext context) {
    final selesai = swap.items.length - swap.belumSelesai;
    final keadaan = swap.diserahkan
        ? 'diserahkan → Riwayat'
        : swap.semuaSelesai
        ? 'semua item selesai'
        : '$selesai/${swap.items.length} item selesai';
    return _Kotak(
      children: [
        ListTile(
          title: Text(
            swap.documentNumber,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${swap.isTiruan ? 'Tiruan' : 'Pesanan asli'} · $keadaan\n'
            '${swap.items.map((i) => i.catatan).join('\n')}',
            style: const TextStyle(fontSize: 12),
          ),
          isThreeLine: true,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          child: Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderStatusPage(orderId: swap.orderId),
                  ),
                ),
                child: const Text('Buka'),
              ),
              // Serah terima kasih tiruan → pesanan pindah ke Riwayat, dan
              // penjaga "satu pesanan" tidak lagi menahan checkout.
              if (swap.isTiruan && !swap.diserahkan)
                TextButton(
                  onPressed: swap.semuaSelesai
                      ? () => itemSwapStore.serahkan(swap.orderId)
                      : null,
                  child: const Text('Tandai diserahkan'),
                ),
              TextButton(
                onPressed: () => itemSwapStore.hapus(swap.orderId),
                child: const Text(
                  'Hapus',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
