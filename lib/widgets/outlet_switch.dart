import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/cart_store.dart';
import '../data/models/outlet.dart';
import '../data/outlet_store.dart';

/// Pindah ke [target] setelah memastikan pembeli tahu konsekuensinya.
///
/// Aturan server: satu pembeli hanya boleh punya satu keranjang aktif —
/// menambah menu di outlet lain otomatis **mengosongkan** keranjang outlet
/// sebelumnya. Karena itu perpindahan outlet saat keranjang masih berisi harus
/// dikonfirmasi lebih dulu (aturan 6 pada dokumen API Aplikasi Customer).
///
/// Mengembalikan true bila outlet jadi dipindah.
Future<bool> switchOutlet(BuildContext context, Outlet target) async {
  final current = outletStore.outlet;
  if (current != null && current.id == target.id) return false;

  // Keranjang kosong (atau milik outlet yang sama) → tidak ada yang hilang.
  final cart = cartStore.cart.value;
  final needsConfirm = cart.items.isNotEmpty && cart.outletId != target.id;

  if (needsConfirm) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pindah outlet?'),
        content: Text(
          'Keranjang Anda berisi ${cart.count} item dari '
          '${current?.name ?? 'outlet sebelumnya'}. Berpindah ke '
          '${target.name} akan mengosongkan keranjang itu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.maroon700,
            ),
            child: const Text('Pindah & kosongkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
  }

  outletStore.select(target);
  return true;
}
