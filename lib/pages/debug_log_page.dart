import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/app_log.dart';
import '../widgets/app_top_bar.dart';

/// Halaman Log — membaca jejak aplikasi langsung dari dalam HP.
///
/// Ada karena pengujian dilakukan di perangkat, di mana konsol `flutter run`
/// tidak selalu terjangkau (mis. aplikasi dibuka dari launcher, atau masalah
/// baru muncul beberapa menit kemudian). Tombol salin menghasilkan teks siap
/// tempel ke chat/tiket, dengan token & API key sudah tersamar.
///
/// Hanya tersedia pada build debug ([AppLog.enabled]).
class DebugLogPage extends StatefulWidget {
  const DebugLogPage({super.key});

  @override
  State<DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends State<DebugLogPage> {
  /// Saring berdasarkan tag, mis. `PAY`. Kosong = tampilkan semua.
  String _filter = '';

  List<LogEntry> get _visible {
    final all = AppLog.entries;
    if (_filter.isEmpty) return all;
    return all.where((e) => e.tag == _filter).toList();
  }

  List<String> get _tags {
    final tags = AppLog.entries.map((e) => e.tag).toSet().toList()..sort();
    return tags;
  }

  Future<void> _copy() async {
    final entries = _visible;
    if (entries.isEmpty) return;
    await Clipboard.setData(
      ClipboardData(text: entries.map((e) => e.toString()).join('\n')),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${entries.length} baris log disalin.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: 'Log Aplikasi',
        actions: [
          IconButton(
            tooltip: 'Salin',
            icon: const Icon(Icons.copy),
            onPressed: _copy,
          ),
          IconButton(
            tooltip: 'Bersihkan',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              AppLog.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: AppLog.revision,
        builder: (context, _, __) {
          final entries = _visible;
          return Column(
            children: [
              _TagFilter(
                tags: _tags,
                active: _filter,
                onPick: (t) => setState(() => _filter = t),
              ),
              Expanded(
                child: entries.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Belum ada log.\nJalankan alurnya dulu, lalu buka '
                            'halaman ini lagi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.grey600),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemBuilder: (context, i) =>
                            _EntryTile(entry: entries[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TagFilter extends StatelessWidget {
  const _TagFilter({
    required this.tags,
    required this.active,
    required this.onPick,
  });

  final List<String> tags;
  final String active;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _chip('Semua', active.isEmpty, () => onPick('')),
          for (final tag in tags)
            _chip(tag, active == tag, () => onPick(tag)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.maroon700 : AppColors.creamSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.grey100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? AppColors.white : AppColors.grey600,
          ),
        ),
      ),
    ),
  );
}

class _EntryTile extends StatefulWidget {
  const _EntryTile({required this.entry});

  final LogEntry entry;

  @override
  State<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<_EntryTile> {
  /// Panjang `detail` yang ditampilkan sebelum dibentangkan.
  ///
  /// Body respons API bisa ribuan karakter; menampilkan semuanya sekaligus
  /// membuat daftar log tak bisa digulir dengan nyaman.
  static const int _ringkas = 400;

  bool _expanded = false;

  Future<void> _copyEntry() async {
    await Clipboard.setData(ClipboardData(text: widget.entry.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Baris log disalin.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final color = switch (entry.level) {
      LogLevel.info => AppColors.grey600,
      LogLevel.warn => AppColors.warning,
      LogLevel.error => AppColors.error,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.clock,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppColors.grey400,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.tag,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                entry.message,
                style: TextStyle(
                  fontSize: 12.5,
                  color: entry.level == LogLevel.info
                      ? AppColors.textDark
                      : color,
                  fontWeight: entry.level == LogLevel.info
                      ? FontWeight.normal
                      : FontWeight.w600,
                ),
              ),
            ),
            InkWell(
              onTap: _copyEntry,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.copy, size: 14, color: AppColors.grey400),
              ),
            ),
          ],
        ),
        if (entry.detail != null) ...[
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: _Detail(
              text: entry.detail!,
              expanded: _expanded,
              ringkas: _ringkas,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
          ),
        ],
      ],
    );
  }
}

/// Isi `detail` sebuah baris log — dipendekkan sampai diminta dibentangkan.
class _Detail extends StatelessWidget {
  const _Detail({
    required this.text,
    required this.expanded,
    required this.ringkas,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final int ringkas;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final panjang = text.length > ringkas;
    final tampil = expanded || !panjang
        ? text
        : '${text.substring(0, ringkas)}…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          tampil,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: AppColors.grey600,
          ),
        ),
        if (panjang)
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                expanded
                    ? 'Tutup'
                    : 'Lihat selengkapnya (${text.length} karakter)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.maroon700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
