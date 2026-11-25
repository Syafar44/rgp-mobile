import 'package:flutter/material.dart';

import '../core/config/app_features.dart';
import '../core/network/api_error.dart';
import '../core/push/push_service.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatter.dart';
import '../data/item_swap_store.dart';
import '../data/models/item_swap.dart';
import '../data/models/order.dart';
import '../data/order_repository.dart';
import 'item_swap_page.dart';
import 'payment_page.dart';

/// Halaman status pesanan — layar utama setelah pembayaran berhasil.
///
/// Menampilkan tahapan pesanan, nomor pesanan besar-besar (dipakai pembeli
/// saat mengambil di outlet), lalu rincian pesanannya di bawah. Tarik layar ke
/// bawah untuk memuat ulang statusnya.
///
/// Halaman ini juga dipakai saat membuka pesanan dari tab Pesanan & Riwayat.
class OrderStatusPage extends StatefulWidget {
  const OrderStatusPage({
    super.key,
    required this.orderId,
    this.initialOrder,
    this.justPaid = false,
  });

  final int orderId;

  /// Data awal (mis. hasil pencarian setelah pembayaran) supaya layar langsung
  /// terisi sementara detail terbaru diambil di latar.
  final Order? initialOrder;

  /// True bila halaman dibuka tepat setelah pembayaran berhasil.
  final bool justPaid;

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
  Order? _order;

  /// Terisi bila halaman ini dibuka untuk pesanan yang pembayarannya belum
  /// selesai — yang ditampilkan ajakan melunasi, bukan status.
  Order? _resumable;

  bool _loading = false;
  bool _cancelling = false;
  String? _error;

  /// True bila pesanan berubah di halaman ini (dibatalkan) — daftar di
  /// belakangnya perlu memuat ulang.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _load();
    // Push tentang pesanan INI yang tiba saat halaman terbuka → ambil status
    // terbaru. Status di dalam push sendiri sengaja tidak dipakai: bisa saja
    // pesanan sudah berubah lagi, jadi server tetap satu-satunya acuan.
    pushService.lastForeground.addListener(_onPush);
    // TODO(ganti-item): hapus gate saat modul dirilis
    if (kFiturGantiItem) itemSwapStore.state.addListener(_onSwap);
  }

  @override
  void dispose() {
    pushService.lastForeground.removeListener(_onPush);
    itemSwapStore.state.removeListener(_onSwap);
    super.dispose();
  }

  /// Keadaan Ganti Item berubah (pengganti dipilih, simulasi) →
  /// tempelkan ulang tanpa menunggu server.
  void _onSwap() {
    final order = _order;
    if (order == null || !mounted) return;
    setState(() {
      _order =
          itemSwapStore.pesananTiruan(order.id) ?? itemSwapStore.overlay(order);
      _changed = true;
    });
  }

  /// Buka Pilih Pengganti untuk [asal].
  Future<void> _openSwap(ItemSwap asal) async {
    // TODO(ganti-item): hapus gate saat modul dirilis
    if (!kFiturGantiItem) return;
    final order = _order;
    if (order == null) return;
    final selesai = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemSwapPage(order: order, asal: asal),
      ),
    );
    if (selesai != true || !mounted) return;
    final sisa = itemSwapStore.of(order.id)?.belumSelesai ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sisa > 0
              ? 'Tersimpan. Masih ada $sisa item lagi yang perlu dipilih.'
              : 'Semua item selesai. Pesanan lanjut disiapkan.',
        ),
      ),
    );
  }

  void _onPush() {
    final payload = pushService.lastForeground.value;
    if (payload == null || payload.orderId != widget.orderId) return;
    _load();
  }

  Future<void> _load() async {
    if (widget.orderId <= 0) {
      // Pesanan yang belum lunas memang belum punya id numerik — pesanan POS
      // baru terbentuk setelah pembayaran masuk. Bukan kerusakan, jadi
      // jangan ditampilkan sebagai galat buntu: antar pembeli menyelesaikan
      // pembayarannya.
      final pending = widget.initialOrder;
      if (pending != null && pending.isAwaitingPayment) {
        setState(() {
          _order = null;
          _loading = false;
          _error = null;
          _resumable = pending;
        });
        return;
      }
      // Tanpa id yang sah, detail tidak bisa diambil dan status tidak bisa
      // dipastikan. Jangan menampilkan kerangka halaman berisi kolom kosong
      // seolah pesanannya ada — katakan apa adanya.
      setState(() {
        _order = null;
        _loading = false;
        _error =
            'Pesanan ini belum bisa dibuka karena nomornya belum dikenali '
            'sistem. Buka daftar Pesanan untuk memeriksanya.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await orderRepository.detail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Jangan buang data yang sudah tampil; cukup tandai gagal menyegarkan.
        _error = apiErrorMessage(e, fallback: 'Gagal memuat status pesanan.');
        _loading = false;
      });
    }
  }

  Future<void> _cancel() async {
    final order = _order;
    if (order == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: Text(
          'Pesanan ${order.documentNumber} akan dibatalkan dan tidak bisa '
          'dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Ya, batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final updated = await orderRepository.cancel(order.id);
      if (!mounted) return;
      setState(() {
        _order = updated;
        _changed = true;
        _cancelling = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pesanan dibatalkan.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    // Kartu peringatan, tanda item, catatan penggantian, dan selisih di kartu
    // Pembayaran semuanya bergantung pada `swap` — null = tidak ada jejaknya.
    // TODO(ganti-item): hapus gate saat modul dirilis
    final swap = !kFiturGantiItem || order == null
        ? null
        : itemSwapStore.of(order.id);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.creamSurface,
        appBar: AppBar(
          backgroundColor: AppColors.creamSurface,
          foregroundColor: AppColors.textDark,
          surfaceTintColor: AppColors.creamSurface,
          centerTitle: true,
          elevation: 0,
          title: const Text(
            'Pickup',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _changed),
          ),
        ),
        body: order == null
            ? (_loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.maroon700,
                      ),
                    )
                  : _resumable != null
                  ? _BelumDibayarView(order: _resumable!)
                  : _ErrorView(message: _error, onRetry: _load))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.maroon700,
                child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (swap != null && order.status.needsAction)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: _PerluTindakanCard(
                          swap: swap,
                          onPilih: () => _openSwap(swap.berikutnya!),
                        ),
                      ),
                    _StatusHeader(order: order, justPaid: widget.justPaid),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          if (_error != null) ...[
                            _RefreshFailedNotice(message: _error!),
                            const SizedBox(height: 12),
                          ],
                          _DetailCard(order: order),
                          const SizedBox(height: 12),
                          _ItemsCard(
                            order: order,
                            swap: swap,
                            onPilihPengganti: _openSwap,
                          ),
                          if (swap != null && swap.selesaiSaja.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _CatatanPenggantianCard(swap: swap),
                          ],
                          const SizedBox(height: 12),
                          _PaymentCard(order: order, swap: swap),
                          if (order.status.canCancel) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: OutlinedButton.icon(
                                onPressed: _cancelling ? null : _cancel,
                                icon: _cancelling
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.error,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.close,
                                        color: AppColors.error,
                                        size: 18,
                                      ),
                                label: const Text(
                                  'Batalkan Pesanan',
                                  style: TextStyle(color: AppColors.error),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.error,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// =============================================================================
// HEADER: tahapan + nomor pesanan
// =============================================================================

/// Tahapan pesanan.
///
/// Server belum punya status "siap diambil", jadi tahap tengah baru menyala
/// setelah pesanan selesai. Begitu backend menambahkannya, cukup ubah
/// [_stepOf].
enum _Step { diproses, siap, selesai }

_Step _stepOf(Order order) {
  // `active` = kasir sudah serah terima; `app_ready` = tinggal diambil.
  if (order.status == OrderStatus.active) return _Step.selesai;
  if (order.status.isReady) return _Step.siap;
  return _Step.diproses;
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.order, required this.justPaid});

  final Order order;
  final bool justPaid;

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status.isCancelled;
    final step = _stepOf(order);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      color: AppColors.creamSurface,
      child: Column(
        children: [
          if (!cancelled) _Stepper(step: step),
          const SizedBox(height: 24),
          const Text(
            'ID Order',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          // Nomor pesanan inilah yang disebutkan ke kasir. Belum ada nomor
          // antrian dari server, jadi nomor pesanan yang ditampilkan.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: SelectableText(
              order.documentNumber,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _StatusMessage(order: order, justPaid: justPaid),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.step});

  final _Step step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepItem(
          icon: Icons.sync,
          label: 'Sedang\nDiproses',
          active: step.index >= _Step.diproses.index,
          filled: step == _Step.diproses,
        ),
        _connector(done: step.index >= _Step.siap.index),
        _stepItem(
          icon: Icons.inventory_2_outlined,
          label: 'Siap\nDi-Pickup',
          active: step.index >= _Step.siap.index,
          filled: step == _Step.siap,
        ),
        _connector(done: step.index >= _Step.selesai.index),
        _stepItem(
          icon: Icons.check,
          label: 'Pesanan\nSelesai',
          active: step.index >= _Step.selesai.index,
          filled: step == _Step.selesai,
        ),
      ],
    );
  }

  Widget _stepItem({
    required IconData icon,
    required String label,
    required bool active,
    required bool filled,
  }) {
    final color = active ? AppColors.maroon700 : AppColors.grey400;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppColors.maroon700 : AppColors.white,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(
              icon,
              size: 24,
              color: filled ? AppColors.white : color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.25,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? AppColors.textDark : AppColors.grey400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _connector({required bool done}) => Padding(
    padding: const EdgeInsets.only(top: 25),
    child: SizedBox(
      width: 28,
      child: Divider(
        thickness: 2,
        color: done ? AppColors.maroon700 : AppColors.grey300,
      ),
    ),
  );
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.order, required this.justPaid});

  final Order order;
  final bool justPaid;

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status.isCancelled;
    final done = order.status == OrderStatus.active;
    final perluTindakan = order.status.needsAction;

    final title = cancelled
        ? 'Pesanan Dibatalkan'
        : done
        ? 'Pesanan Selesai'
        : perluTindakan
        ? 'Perlu Tindakan'
        : justPaid
        ? 'Pembayaran Berhasil'
        : 'Pesanan Diterima';

    final message = cancelled
        ? 'Pesanan ini sudah dibatalkan. Silakan pesan lagi bila diperlukan.'
        : done
        ? 'Terima kasih! Pesanan sudah diambil di outlet.'
        : perluTindakan
        ? 'Ada item yang habis di outlet. Pilih penggantinya agar pesanan '
              'bisa disiapkan.'
        : 'Mohon tunggu sebentar, staf kami sedang menyiapkan pesanan kamu. '
              'Perlihatkan nomor di atas saat mengambil.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.grey600),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DETAIL PESANAN
// =============================================================================

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return _Card(
      icon: Icons.receipt_long_outlined,
      title: 'Detail Pesanan',
      // Diberi label supaya tidak tertukar dengan "Jam ambil" di bawahnya —
      // keduanya jam WITA dan biasanya berselisih satu jam.
      trailing: order.createdAt == null
          ? null
          : 'Dipesan ${formatTanggal(order.createdAt!)} WITA',
      children: [
        _row(Icons.confirmation_number_outlined, 'Nomor', order.documentNumber),
        _row(Icons.storefront, 'Pickup di', order.outletName),
        if (order.pickupAt != null)
          _row(
            Icons.schedule,
            'Jam ambil',
            '${formatTanggal(order.pickupAt!)} WITA',
          ),
        if (order.keterangan.isNotEmpty)
          _row(Icons.sticky_note_2_outlined, 'Catatan', order.keterangan),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.grey400),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.grey600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({
    required this.order,
    required this.onPilihPengganti,
    this.swap,
  });

  final Order order;

  /// Keadaan Ganti Item pesanan ini. Null bila tidak ada item habis.
  final OrderSwap? swap;

  final ValueChanged<ItemSwap> onPilihPengganti;

  @override
  Widget build(BuildContext context) {
    return _Card(
      icon: Icons.shopping_bag_outlined,
      title: 'Item Pesanan',
      trailing: '${order.itemCount} item',
      children: [
        if (!order.hasLines)
          Text(
            'Rincian item tidak tersedia.',
            style: TextStyle(fontSize: 12, color: AppColors.grey600),
          )
        else
          for (final line in order.lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${line.quantity}× ${line.title}',
                    style: _gaya(line),
                  ),
                ),
                Text(formatRupiah(line.subtotal), style: _gaya(line)),
              ],
            ),
            // Isi paket — qty-nya sudah dikali jumlah paket oleh server.
            for (final prop in line.props)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 2),
                child: Text(
                  '• ${prop.title} × ${prop.quantity}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grey600,
                  ),
                ),
              ),
            if (line.tidakTersedia) _penanda(line),
            for (final p in line.pengganti)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Pengganti', warna: AppColors.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${p.quantity}× ${p.title}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Text(
                      formatRupiah(p.subtotal),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  /// Item yang sudah diganti dicoret — bukan lagi yang disiapkan.
  TextStyle _gaya(OrderLine line) => TextStyle(
    fontSize: 13,
    color: line.sudahDiselesaikan ? AppColors.grey400 : AppColors.textDark,
    decoration: line.sudahDiselesaikan ? TextDecoration.lineThrough : null,
  );

  /// Tanda di bawah item habis: label keadaannya, plus tombol pilih bila
  /// belum diputuskan.
  Widget _penanda(OrderLine line) {
    final asal = swap?.items.where((i) => i.cocokDengan(line)).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (line.pengganti.isNotEmpty)
            const _Label('Diganti', warna: AppColors.grey600)
          else
            const _Label('Tidak tersedia', warna: AppColors.warning),
          const Spacer(),
          if (line.menungguTindakan && asal != null)
            TextButton(
              onPressed: () => onPilihPengganti(asal),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.maroon700,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                'Pilih Pengganti',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

/// Label kecil berwarna, mis. "Pengganti" / "Tidak tersedia".
class _Label extends StatelessWidget {
  const _Label(this.text, {required this.warna});

  final String text;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: warna,
        ),
      ),
    );
  }
}

/// Peringatan di atas halaman: ada item habis yang menunggu keputusan.
class _PerluTindakanCard extends StatelessWidget {
  const _PerluTindakanCard({required this.swap, required this.onPilih});

  final OrderSwap swap;
  final VoidCallback onPilih;

  @override
  Widget build(BuildContext context) {
    final sisa = swap.belumSelesai;
    final berikutnya = swap.berikutnya;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.report_problem_outlined,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$sisa item tidak tersedia',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Outlet kehabisan item ini setelah pesanan dibayar. Pilih '
            'pengganti dari outlet yang sama, minimal senilai item tersebut. '
            'Pesanan disiapkan setelah semua item dipilih.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.grey600,
            ),
          ),
          if (berikutnya != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: onPilih,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  sisa > 1
                      ? 'Pilih Pengganti · ${berikutnya.title}'
                      : 'Pilih Pengganti',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Catatan penggantian — tetap tampil setelah pesanan masuk Riwayat.
class _CatatanPenggantianCard extends StatelessWidget {
  const _CatatanPenggantianCard({required this.swap});

  final OrderSwap swap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      icon: Icons.swap_horiz,
      title: 'Catatan Penggantian',
      children: [
        for (final i in swap.selesaiSaja)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: AppColors.grey400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    i.catatan,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.order, this.swap});

  final Order order;

  /// Penggantian yang menambah selisih. Null bila tidak ada item habis.
  final OrderSwap? swap;

  @override
  Widget build(BuildContext context) {
    // Seluruh biaya yang ditanggung pembeli dijadikan satu baris.
    //
    // Label dari server menyebut rumusnya ("Biaya QRIS (0,9% + PPN 11%)") —
    // berguna untuk menelusuri masalah, tapi bukan yang perlu dibaca pembeli
    // di halaman tunggu. Nilainya tetap dari server; yang diganti hanya
    // sebutannya.
    final biaya = order.displayFee;
    final selisih = swap?.totalSelisihDibayar ?? 0;

    return _Card(
      icon: Icons.payments_outlined,
      title: 'Pembayaran',
      children: [
        _row('Subtotal', formatRupiah(order.displaySubtotal)),
        if (order.discountAmount > 0)
          _row('Diskon', '- ${formatRupiah(order.discountAmount)}'),
        if (biaya > 0) _row('Biaya Layanan', formatRupiah(biaya)),
        if (selisih > 0)
          _row('Bayar Selisih Pengganti', formatRupiah(selisih)),
        const Divider(height: 18),
        _row(
          'Total Dibayar',
          formatRupiah(order.displayTotal + selisih),
          bold: true,
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: bold ? 14 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? AppColors.textDark : AppColors.grey600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: bold ? AppColors.maroon700 : AppColors.textDark,
          ),
        ),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.maroon700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.grey600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _RefreshFailedNotice extends StatelessWidget {
  const _RefreshFailedNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Status mungkin belum terbaru: $message',
              style: const TextStyle(fontSize: 12, color: AppColors.grey600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              message ?? 'Gagal memuat status pesanan.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey600),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.maroon700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tampilan untuk pesanan yang pembayarannya belum selesai.
///
/// Menggantikan pesan galat lama ("nomornya belum dikenali sistem") yang
/// benar secara teknis tapi buntu bagi pembeli: yang sebenarnya terjadi
/// adalah pembayarannya belum tuntas, dan itu masih bisa dilanjutkan.
class _BelumDibayarView extends StatelessWidget {
  const _BelumDibayarView({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.maroon50,
              ),
              child: const Icon(
                Icons.payments_outlined,
                size: 40,
                color: AppColors.maroon700,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pembayaran Belum Selesai',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pesanan ini belum dibayar, jadi outlet belum mulai '
              'menyiapkannya. Lanjutkan pembayaran untuk memprosesnya.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.grey600,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.creamSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    'Nomor pesanan',
                    style: TextStyle(fontSize: 11, color: AppColors.grey600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.documentNumber,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.maroon700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await openResumePayment(context, order);
                  // Halaman ini tidak lagi berguna setelahnya: entah sudah
                  // lunas (halaman status yang benar dibuka dari sana) atau
                  // masih menunggu bayar.
                  navigator.pop(true);
                },
                icon: const Icon(Icons.arrow_forward, size: 20),
                label: const Text('Lanjutkan Pembayaran'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon700,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
