import 'package:flutter/material.dart';

import '../core/network/api_error.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatter.dart';
import '../data/item_swap_repository.dart';
import '../data/item_swap_store.dart';
import '../data/models/checkout_result.dart';
import '../data/models/item_swap.dart';
import '../data/models/order.dart';
import '../widgets/network_guard.dart';
import '../widgets/product_card.dart';
import 'payment_page.dart';

/// Halaman Pilih Pengganti — satu item habis diselesaikan di sini.
///
/// Pembeli memilih satu atau lebih produk (dengan qty) dari outlet yang sama
/// sebagai pengganti. Hitungannya selalu terhadap nilai yang sudah dibayar
/// untuk item itu:
/// - total pengganti < nilai dibayar → belum bisa dikonfirmasi; refund belum
///   tersedia, jadi pembeli menambah pilihan sampai senilai
/// - total pengganti = nilai dibayar → langsung dikonfirmasi
/// - total pengganti > nilai dibayar → bayar selisihnya dulu lewat halaman
///   Pembayaran yang sama dengan checkout
///
/// Ditutup dengan hasil `true` bila item ini sudah diselesaikan.
class ItemSwapPage extends StatefulWidget {
  const ItemSwapPage({super.key, required this.order, required this.asal});

  final Order order;

  /// Item habis yang sedang dicarikan penggantinya.
  final ItemSwap asal;

  @override
  State<ItemSwapPage> createState() => _ItemSwapPageState();
}

class _ItemSwapPageState extends State<ItemSwapPage> {
  List<SwapSection> _sections = const [];
  bool _loading = true;
  String? _error;
  bool _saving = false;

  /// Qty terpilih per id menu.
  final Map<int, int> _qty = {};

  final Map<int, SwapCandidate> _byId = {};

  ItemSwap get _asal => widget.asal;

  List<SwapPick> get _picks => [
    for (final e in _qty.entries)
      if (e.value > 0 && _byId[e.key] != null) _byId[e.key]!.pick(e.value),
  ];

  int get _total => _picks.fold(0, (a, p) => a + p.subtotal);

  int get _selisih => hitungSelisih(_asal.nilaiAsal, _total);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sections = await itemSwapRepository.kandidat(widget.order);
      if (!mounted) return;
      setState(() {
        _sections = sections;
        _byId
          ..clear()
          ..addAll({
            for (final s in sections)
              for (final c in s.items) c.menuId: c,
          });
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, fallback: 'Gagal memuat produk pengganti.');
        _loading = false;
      });
    }
  }

  void _ubah(SwapCandidate c, int delta) {
    final next = ((_qty[c.menuId] ?? 0) + delta).clamp(0, c.stok);
    setState(() => _qty[c.menuId] = next);
  }

  // --- Aksi ------------------------------------------------------------------

  Future<void> _lanjut() async {
    final picks = _picks;
    // Belum senilai item yang dibayar — tombolnya pun sudah terkunci.
    if (picks.isEmpty || _saving || _selisih < 0) return;

    final setuju = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RingkasanSheet(asal: _asal, picks: picks),
    );
    if (setuju != true || !mounted) return;

    final selisih = hitungSelisih(_asal.nilaiAsal, _total);
    if (selisih == 0) {
      await _simpan(picks);
      return;
    }

    // Pengganti lebih mahal → kekurangannya dibayar dulu, lewat alur
    // pembayaran yang sama dengan checkout (penjaga jaringan + dialog siap
    // bayar). Pengganti baru tersimpan setelah lunas.
    if (!await ensureNetworkReady(context) || !mounted) return;
    final urutan =
        (itemSwapStore.of(widget.order.id)?.items.indexOf(_asal) ?? 0) + 1;
    final lunas = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          simulasi: true,
          checkout: CheckoutResult(
            orderId: '${widget.order.documentNumber}-S$urutan',
            outletId: widget.order.outletId,
            status: 'pending',
            statusLabel: 'Menunggu pembayaran',
            subtotalAmount: selisih,
            paymentMethod: 'bni',
          ),
        ),
      ),
    );
    if (lunas != true || !mounted) return;
    await _simpan(picks, selisihDibayar: selisih);
  }

  Future<void> _simpan(List<SwapPick> picks, {int selisihDibayar = 0}) async {
    setState(() => _saving = true);
    try {
      await itemSwapRepository.simpanPengganti(
        widget.order,
        _asal,
        picks,
        selisihDibayar: selisihDibayar,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(apiErrorMessage(e, fallback: 'Gagal menyimpan pengganti.'));
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  // --- Tampilan --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final swap = itemSwapStore.of(widget.order.id);
    final jumlah = swap?.items.length ?? 1;
    final urutan = (swap?.items.indexOf(_asal) ?? 0) + 1;

    return Scaffold(
      backgroundColor: AppColors.creamSurface,
      appBar: AppBar(
        backgroundColor: AppColors.creamSurface,
        foregroundColor: AppColors.textDark,
        surfaceTintColor: AppColors.creamSurface,
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'Pilih Pengganti',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          _HabisHeader(
            asal: _asal,
            urutan: jumlah > 1 ? 'Item $urutan dari $jumlah' : null,
          ),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: _RingkasanBar(
        nilaiDibayar: _asal.nilaiAsal,
        totalPengganti: _total,
        selisih: _selisih,
        adaPilihan: _picks.isNotEmpty,
        saving: _saving,
        onLanjut: _lanjut,
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.maroon700),
      );
    }
    if (_error != null) {
      return _Pesan(
        icon: Icons.cloud_off_outlined,
        text: _error!,
        onRetry: _load,
      );
    }
    if (_sections.isEmpty) {
      return const _Pesan(
        icon: Icons.inventory_2_outlined,
        text:
            'Tidak ada produk lain yang tersedia di outlet ini. Hubungi '
            'outlet dengan menyebut nomor pesanan Anda.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        for (final s in _sections) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(
              s.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          for (final c in s.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _KandidatTile(
                kandidat: c,
                qty: _qty[c.menuId] ?? 0,
                enabled: !_saving,
                onTambah: () => _ubah(c, 1),
                onKurang: () => _ubah(c, -1),
              ),
            ),
        ],
      ],
    );
  }
}

// =============================================================================
// HEADER
// =============================================================================

class _HabisHeader extends StatelessWidget {
  const _HabisHeader({required this.asal, this.urutan});

  final ItemSwap asal;
  final String? urutan;

  @override
  Widget build(BuildContext context) {
    final harga = asal.quantity > 0 ? asal.nilaiAsal ~/ asal.quantity : 0;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.remove_shopping_cart_outlined,
            color: AppColors.warning,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  urutan == null
                      ? 'Item tidak tersedia'
                      : 'Item tidak tersedia · $urutan',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${asal.title} ×${asal.quantity}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sudah dibayar ${formatRupiah(asal.nilaiAsal)}'
                  '${asal.quantity > 1 ? ' (${formatRupiah(harga)} × ${asal.quantity})' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DAFTAR PRODUK
// =============================================================================

class _KandidatTile extends StatelessWidget {
  const _KandidatTile({
    required this.kandidat,
    required this.qty,
    required this.enabled,
    required this.onTambah,
    required this.onKurang,
  });

  final SwapCandidate kandidat;
  final int qty;
  final bool enabled;
  final VoidCallback onTambah;
  final VoidCallback onKurang;

  @override
  Widget build(BuildContext context) {
    final p = kandidat.product;
    final dipilih = qty > 0;
    final penuh = qty >= kandidat.stok;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dipilih ? AppColors.maroon700 : AppColors.grey100,
          width: dipilih ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: ProductImage(imageUrl: p.imageUrl),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatRupiah(kandidat.harga),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.maroon700,
                  ),
                ),
                Text(
                  'Sisa ${kandidat.stok}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!dipilih)
            OutlinedButton(
              onPressed: enabled ? onTambah : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.maroon700,
                side: const BorderSide(color: AppColors.maroon700),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Pilih'),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QtyButton(
                  icon: Icons.remove,
                  onTap: enabled ? onKurang : null,
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    '$qty',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _QtyButton(
                  icon: Icons.add,
                  onTap: enabled && !penuh ? onTambah : null,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final aktif = onTap != null;
    return Material(
      color: aktif ? AppColors.maroon700 : AppColors.grey100,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 16,
            color: aktif ? AppColors.white : AppColors.grey400,
          ),
        ),
      ),
    );
  }
}

class _Pesan extends StatelessWidget {
  const _Pesan({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.grey400),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey600),
            ),
            if (onRetry != null) ...[
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
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// RINGKASAN (sticky)
// =============================================================================

class _RingkasanBar extends StatelessWidget {
  const _RingkasanBar({
    required this.nilaiDibayar,
    required this.totalPengganti,
    required this.selisih,
    required this.adaPilihan,
    required this.saving,
    required this.onLanjut,
  });

  final int nilaiDibayar;
  final int totalPengganti;
  final int selisih;
  final bool adaPilihan;
  final bool saving;
  final VoidCallback onLanjut;

  @override
  Widget build(BuildContext context) {
    final kurang = selisih > 0;
    // Pengganti belum senilai item yang dibayar. Refund belum tersedia, jadi
    // sisanya tidak bisa dikembalikan — pembeli perlu menambah pilihan.
    final belumSenilai = adaPilihan && selisih < 0 ? -selisih : 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _baris('Nilai dibayar', formatRupiah(nilaiDibayar)),
              const SizedBox(height: 4),
              _baris('Total pengganti', formatRupiah(totalPengganti)),
              const Divider(height: 16),
              _baris(
                'Selisih',
                !adaPilihan
                    ? '—'
                    : kurang
                    ? '+ ${formatRupiah(selisih)}'
                    : selisih < 0
                    ? '- ${formatRupiah(-selisih)}'
                    : formatRupiah(0),
                tebal: true,
                warna: kurang || belumSenilai > 0
                    ? AppColors.warning
                    : AppColors.textDark,
              ),
              if (belumSenilai > 0) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pengganti minimal senilai item yang dibayar. Tambah '
                        '${formatRupiah(belumSenilai)} lagi.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: adaPilihan && belumSenilai == 0 && !saving
                      ? onLanjut
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.maroon700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Text(
                          !adaPilihan
                              ? 'Pilih produk pengganti'
                              : belumSenilai > 0
                              ? 'Tambah ${formatRupiah(belumSenilai)} lagi'
                              : kurang
                              ? 'Bayar Selisih ${formatRupiah(selisih)}'
                              : 'Konfirmasi Pengganti',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _baris(
    String label,
    String nilai, {
    bool tebal = false,
    Color warna = AppColors.textDark,
  }) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: tebal ? 14 : 13,
            fontWeight: tebal ? FontWeight.bold : FontWeight.normal,
            color: tebal ? AppColors.textDark : AppColors.grey600,
          ),
        ),
      ),
      Text(
        nilai,
        style: TextStyle(
          fontSize: tebal ? 15 : 13,
          fontWeight: tebal ? FontWeight.bold : FontWeight.w600,
          color: warna,
        ),
      ),
    ],
  );
}

/// Ringkasan sebelum → sesudah, ditampilkan sebelum pengganti disimpan.
class _RingkasanSheet extends StatelessWidget {
  const _RingkasanSheet({required this.asal, required this.picks});

  final ItemSwap asal;
  final List<SwapPick> picks;

  @override
  Widget build(BuildContext context) {
    final total = picks.fold<int>(0, (a, p) => a + p.subtotal);
    final selisih = hitungSelisih(asal.nilaiAsal, total);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Periksa Penggantian',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            _label('Sebelum'),
            _item(
              '${asal.title} ×${asal.quantity}',
              asal.nilaiAsal,
              coret: true,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Icon(
                Icons.arrow_downward,
                size: 18,
                color: AppColors.grey400,
              ),
            ),
            _label('Sesudah'),
            for (final p in picks)
              _item('${p.title} ×${p.quantity}', p.subtotal),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    selisih > 0 ? 'Bayar selisih' : 'Selisih',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  formatRupiah(selisih),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: selisih > 0
                        ? AppColors.warning
                        : AppColors.maroon700,
                  ),
                ),
              ],
            ),
            if (selisih > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Pengganti tersimpan setelah selisihnya lunas.',
                style: TextStyle(fontSize: 12, color: AppColors.grey600),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  selisih > 0
                      ? 'Lanjut Bayar ${formatRupiah(selisih)}'
                      : 'Simpan Pengganti',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Ubah', style: TextStyle(color: AppColors.grey600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.grey600,
      ),
    ),
  );

  Widget _item(String title, int amount, {bool coret = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: coret ? AppColors.grey600 : AppColors.textDark,
              decoration: coret ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        Text(
          formatRupiah(amount),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: coret ? AppColors.grey600 : AppColors.textDark,
            decoration: coret ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    ),
  );
}
