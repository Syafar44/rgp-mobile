import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/dummy/dummy_data.dart';
import '../widgets/app_top_bar.dart';

/// Outlet (nama + alamat) yang dikembalikan halaman pemilihan outlet.
typedef Outlet = ({String name, String address});

/// Halaman pemilihan **Outlet Panglima**.
///
/// Dibuka dari tombol lokasi di Beranda/Menu & tombol "Ubah" outlet di
/// Konfirmasi Pesanan. Mengembalikan [Outlet] yang dipilih lewat `Navigator.pop`.
class OutletPage extends StatefulWidget {
  const OutletPage({super.key});

  @override
  State<OutletPage> createState() => _OutletPageState();
}

class _OutletPageState extends State<OutletPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final outlets = DummyData.outlets
        .where(
          (o) =>
              o.name.toLowerCase().contains(q) ||
              o.address.toLowerCase().contains(q),
        )
        .toList();

    return Scaffold(
      appBar: const AppTopBar(title: 'Outlet Panglima'),
      body: Column(
        children: [
          _SearchField(
            hint: 'Cari outlet',
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: outlets.isEmpty
                ? const _EmptyText('Outlet tidak ditemukan')
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: outlets.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 68, endIndent: 16),
                    itemBuilder: (context, i) {
                      final o = outlets[i];
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        leading: const _RoundIcon(
                          icon: Icons.storefront,
                          background: AppColors.maroon50,
                          foreground: AppColors.maroon700,
                        ),
                        title: Text(
                          o.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        subtitle: Text(
                          o.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.grey600,
                          ),
                        ),
                        onTap: () => Navigator.pop<Outlet>(context, o),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// HELPER (dipakai bersama OutletPage & AddressPage)
// =============================================================================

/// Kolom pencarian membulat.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.grey400),
          prefixIcon: const Icon(Icons.search, color: AppColors.grey400),
          filled: true,
          fillColor: AppColors.grey100,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: foreground, size: 20),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: const TextStyle(color: AppColors.grey600)),
    );
  }
}
