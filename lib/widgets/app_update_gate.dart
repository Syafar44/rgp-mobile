import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../core/theme/app_colors.dart';
import '../core/update/app_update.dart';
import '../core/utils/app_log.dart';

/// Memeriksa versi baru di Google Play saat aplikasi dibuka & kembali ke
/// depan, lalu menampilkan modal "Update Tersedia".
///
/// - Prioritas update < [kPrioritasWajib] → modal opsional ("Nanti Saja").
///   Setelah ditunda, tidak ditanyakan lagi sampai aplikasi dibuka ulang.
/// - Prioritas ≥ [kPrioritasWajib] → modal wajib: tidak bisa ditutup, dan
///   muncul lagi bila pembeli membatalkan layar update Play.
///
/// "Update Sekarang" membuka layar update penuh milik Google Play; setelah
/// terpasang, aplikasi terbuka lagi sendiri. Dipasang sebagai `home`
/// [MaterialApp] supaya modalnya muncul di atas layar mana pun, termasuk
/// layar masuk.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({
    super.key,
    required this.child,
    this.checker = InAppUpdate.checkForUpdate,
    this.performer = InAppUpdate.performImmediateUpdate,
    this.supported,
  });

  final Widget child;
  final UpdateChecker checker;
  final UpdatePerformer performer;

  /// Null = otomatis: hanya Android. Diisi di test.
  final bool? supported;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  /// Mencegah pemeriksaan bertumpuk (mis. resume beruntun).
  bool _sibuk = false;

  /// Pembeli menunda update opsional — jangan tanya lagi di sesi ini.
  bool _ditunda = false;

  bool get _didukung =>
      widget.supported ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _periksa());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali dari layar update Play / dari latar → periksa lagi. Ini juga
    // yang melanjutkan update langsung yang sempat terputus.
    if (state == AppLifecycleState.resumed) _periksa();
  }

  Future<void> _periksa() async {
    if (!_didukung || _sibuk || !mounted) return;
    _sibuk = true;
    try {
      final info = await widget.checker();
      final rencana = rencanaUpdate(info);
      AppLog.info(
        'UPDATE',
        'cek Play: ${rencana.name}',
        detail:
            'availability=${info.updateAvailability.name} '
            'versionCode=${info.availableVersionCode} '
            'priority=${info.updatePriority} '
            'immediate=${info.immediateUpdateAllowed}',
      );
      switch (rencana) {
        case UpdatePlan.tidakAda:
          return;
        case UpdatePlan.lanjutkan:
          await widget.performer();
          return;
        case UpdatePlan.opsional:
          if (_ditunda) return;
          await _tawarkan(wajib: false);
          return;
        case UpdatePlan.wajib:
          await _tawarkan(wajib: true);
          return;
      }
    } catch (e) {
      // Build debug / bukan dari Play / Play Store tidak ada → abaikan.
      AppLog.warn('UPDATE', 'cek update dilewati', detail: '$e');
    } finally {
      _sibuk = false;
    }
  }

  /// Tampilkan modal; ulangi selama update wajib belum terpasang.
  Future<void> _tawarkan({required bool wajib}) async {
    while (true) {
      if (!mounted) return;
      final update = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UpdateDialog(wajib: wajib),
      );
      if (update != true) {
        _ditunda = true;
        AppLog.info('UPDATE', 'update opsional ditunda');
        return;
      }
      final hasil = await widget.performer();
      AppLog.info('UPDATE', 'layar update Play: ${hasil.name}');
      // Sukses: Play memasang & membuka ulang aplikasi. Batal/gagal pada
      // update wajib → tanya lagi; aplikasi tidak boleh dipakai.
      if (hasil == AppUpdateResult.success || !wajib) {
        if (!wajib) _ditunda = true;
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.wajib});

  final bool wajib;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Tombol kembali tidak menutup modal wajib.
      canPop: !wajib,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // `Center` wajib: slot ikon `AlertDialog` berada di kolom yang
        // meregang selebar dialog, jadi tanpa ini lingkarannya lonjong.
        icon: Center(
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.maroon50,
            ),
            child: const Icon(
              Icons.system_update_outlined,
              color: AppColors.maroon700,
              size: 28,
            ),
          ),
        ),
        title: const Text(
          'Update Tersedia',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          wajib
              ? 'Versi aplikasi ini sudah tidak didukung. Update ke versi '
                    'terbaru untuk melanjutkan.'
              : 'Versi terbaru Roti Gembung Panglima sudah tersedia di Google '
                    'Play. Update sekarang untuk mendapatkan perbaikan dan '
                    'fitur terbaru.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.grey600,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.maroon700,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Update Sekarang'),
            ),
          ),
          if (!wajib)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Nanti Saja',
                  style: TextStyle(color: AppColors.grey600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
