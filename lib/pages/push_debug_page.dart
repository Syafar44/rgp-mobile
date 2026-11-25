import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/push/push_service.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/app_log.dart';
import '../data/push_repository.dart';

/// Diagnosa push notification.
///
/// Menjawab satu pertanyaan: **apakah perangkat ini benar-benar tertaut ke
/// pembeli yang sedang masuk?** Semua nilai dibaca langsung dari SDK OneSignal
/// dan dari `GET /pos/app/v1/push_identity`, bukan dari tebakan aplikasi, lalu
/// keduanya dibandingkan.
class PushDebugPage extends StatefulWidget {
  const PushDebugPage({super.key});

  @override
  State<PushDebugPage> createState() => _PushDebugPageState();
}

class _PushDebugPageState extends State<PushDebugPage> {
  Map<String, String> _info = const {};
  String? _serverId;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final info = await pushService.diagnostics();
    final serverId = await pushService.serverExternalId();
    if (!mounted) return;
    setState(() {
      _info = info;
      _serverId = serverId;
      _loading = false;
    });
  }

  /// Paksa `OneSignal.login()` lagi, walau aplikasi mengira sudah tertaut.
  Future<void> _relink() async {
    setState(() => _working = true);
    await pushService.linkToBuyer(force: true);
    if (!mounted) return;
    setState(() => _working = false);
    await _load();
  }

  Future<void> _askPermission() async {
    setState(() => _working = true);
    // `true` = bila izin pernah ditolak permanen, buka Pengaturan sistem —
    // hanya pada tombol yang ditekan sendiri, tidak pernah otomatis.
    await pushService.askPermission(fallbackToSettings: true);
    if (!mounted) return;
    setState(() => _working = false);
    await _load();
  }

  void _copy() {
    final buffer = StringBuffer('== Diagnosa Push ==\n');
    _info.forEach((k, v) => buffer.writeln('$k: $v'));
    buffer.writeln(
      'External ID dari server: ${_serverId ?? '(gagal diambil)'}',
    );
    if (pushRepository.lastFailure != null) {
      buffer.writeln('Sebab gagal: ${pushRepository.lastFailure}');
    }
    buffer.writeln('\n== Log tag PUSH ==');
    for (final e in AppLog.entries.where((e) => e.tag == 'PUSH')) {
      buffer.writeln(e.toString());
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disalin — siap dikirim ke tim backend.')),
    );
  }

  /// Kesimpulan yang bisa langsung dibaca, bukan deretan angka mentah.
  ({String judul, String pesan, bool baik}) get _kesimpulan {
    final diSdk = _info['External ID di SDK'] ?? '(kosong)';
    final server = _serverId?.trim() ?? '';

    if (_info['SDK siap'] != 'ya') {
      return (
        judul: 'SDK tidak jalan',
        pesan: _info['Sebab'] ?? 'OneSignal belum menyala.',
        baik: false,
      );
    }
    if (server.isEmpty) {
      return (
        judul: 'Server tidak memberi external_id',
        pesan: pushRepository.lastFailure ??
            '`GET /pos/app/v1/push_identity` gagal atau mengembalikan kosong.',
        baik: false,
      );
    }
    if (diSdk == '(kosong)') {
      return (
        judul: 'Perangkat belum tertaut',
        pesan: 'Server sudah memberi external_id, tapi SDK belum menyimpannya. '
            'Tekan "Tautkan ulang" di bawah.',
        baik: false,
      );
    }
    if (diSdk != server) {
      return (
        judul: 'Tertaut ke external_id yang SALAH',
        pesan: 'Yang terpasang di perangkat berbeda dengan yang diminta '
            'server — biasanya sisa tautan dari versi aplikasi sebelumnya. '
            'Tekan "Tautkan ulang".',
        baik: false,
      );
    }
    if (_info['Izin notifikasi'] != 'ya') {
      return (
        judul: 'Tertaut, tapi izin notifikasi mati',
        pesan: 'Backend bisa menemukan perangkat ini, namun notifikasinya '
            'tidak akan tampil. Nyalakan izinnya.',
        baik: false,
      );
    }
    return (
      judul: 'Tertaut dengan benar',
      pesan: 'External ID di perangkat sama dengan yang diberikan server. '
          'Bila backend masih tidak menemukannya, kirim Subscription ID di '
          'bawah untuk dicek di dashboard OneSignal.',
      baik: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnosa Push'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _copy,
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Salin semua',
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _Kesimpulan(hasil: _kesimpulan),
                const SizedBox(height: 20),
                _Baris(
                  label: 'External ID dari server',
                  value: _serverId ?? '(gagal diambil)',
                  penting: true,
                ),
                for (final e in _info.entries)
                  _Baris(
                    label: e.key,
                    value: e.value,
                    penting: e.key == 'External ID di SDK',
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _working ? null : _relink,
                  icon: const Icon(Icons.link),
                  label: const Text('Tautkan ulang (paksa)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.maroon700,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _working ? null : _askPermission,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Minta izin notifikasi'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tautkan ulang memanggil OneSignal.login() lagi walau '
                  'aplikasi mengira sudah tertaut — tidak perlu keluar akun '
                  'atau memasang ulang aplikasi.',
                  style: TextStyle(fontSize: 12, color: AppColors.grey600),
                ),
              ],
            ),
    );
  }
}

class _Kesimpulan extends StatelessWidget {
  const _Kesimpulan({required this.hasil});

  final ({String judul, String pesan, bool baik}) hasil;

  @override
  Widget build(BuildContext context) {
    final warna = hasil.baik ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warna.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasil.baik ? Icons.check_circle_outline : Icons.error_outline,
            color: warna,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasil.judul,
                  style: TextStyle(fontWeight: FontWeight.bold, color: warna),
                ),
                const SizedBox(height: 4),
                Text(
                  hasil.pesan,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({
    required this.label,
    required this.value,
    this.penting = false,
  });

  final String label;
  final String value;
  final bool penting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.grey600),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: penting ? FontWeight.bold : FontWeight.normal,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
