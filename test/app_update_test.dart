// Cek update Google Play (In-App Updates).
//
// Plugin Play dipalsukan lewat `checker`/`performer`, jadi semua jalur modal
// teruji tanpa perangkat: opsional, wajib, ditunda, dibatalkan, terputus.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';

import 'package:roti_gembung_panglima_app/core/update/app_update.dart';
import 'package:roti_gembung_panglima_app/widgets/app_update_gate.dart';

AppUpdateInfo info({
  UpdateAvailability availability = UpdateAvailability.updateAvailable,
  bool immediate = true,
  int priority = 0,
}) => AppUpdateInfo(
  updateAvailability: availability,
  immediateUpdateAllowed: immediate,
  immediateAllowedPreconditions: null,
  flexibleUpdateAllowed: true,
  flexibleAllowedPreconditions: null,
  availableVersionCode: 4,
  installStatus: InstallStatus.unknown,
  packageName: 'id.panglima.tes',
  clientVersionStalenessDays: 1,
  updatePriority: priority,
);

void main() {
  group('rencana update', () {
    test('prioritas < 4 → opsional, ≥ 4 → wajib', () {
      expect(rencanaUpdate(info(priority: 0)), UpdatePlan.opsional);
      expect(rencanaUpdate(info(priority: 3)), UpdatePlan.opsional);
      expect(rencanaUpdate(info(priority: 4)), UpdatePlan.wajib);
      expect(rencanaUpdate(info(priority: 5)), UpdatePlan.wajib);
    });

    test('tidak ada versi baru / tidak diizinkan → tidak ada', () {
      expect(
        rencanaUpdate(
          info(availability: UpdateAvailability.updateNotAvailable),
        ),
        UpdatePlan.tidakAda,
      );
      expect(
        rencanaUpdate(info(availability: UpdateAvailability.unknown)),
        UpdatePlan.tidakAda,
      );
      expect(rencanaUpdate(info(immediate: false)), UpdatePlan.tidakAda);
    });

    test('update terputus → dilanjutkan', () {
      expect(
        rencanaUpdate(
          info(
            availability: UpdateAvailability.developerTriggeredUpdateInProgress,
          ),
        ),
        UpdatePlan.lanjutkan,
      );
    });
  });

  group('modal', () {
    late int cek;
    late int pasang;
    late List<AppUpdateResult> hasilPasang;

    setUp(() {
      cek = 0;
      pasang = 0;
      hasilPasang = [AppUpdateResult.success];
    });

    Future<void> buka(
      WidgetTester tester,
      AppUpdateInfo Function() jawaban, {
      bool supported = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppUpdateGate(
            supported: supported,
            checker: () async {
              cek++;
              return jawaban();
            },
            performer: () async {
              pasang++;
              return hasilPasang.length > 1
                  ? hasilPasang.removeAt(0)
                  : hasilPasang.first;
            },
            child: const Scaffold(body: Text('Beranda')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    void kembaliKeDepan(WidgetTester tester) => tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    testWidgets('opsional: Nanti Saja → tidak ditanya lagi di sesi ini', (
      tester,
    ) async {
      await buka(tester, () => info(priority: 2));
      expect(find.text('Update Tersedia'), findsOneWidget);
      expect(find.text('Nanti Saja'), findsOneWidget);

      await tester.tap(find.text('Nanti Saja'));
      await tester.pumpAndSettle();
      expect(find.text('Update Tersedia'), findsNothing);
      expect(pasang, 0);

      kembaliKeDepan(tester);
      await tester.pumpAndSettle();
      expect(cek, 2, reason: 'tetap diperiksa saat kembali ke depan');
      expect(find.text('Update Tersedia'), findsNothing);
    });

    testWidgets('opsional: Update Sekarang → layar update Play', (
      tester,
    ) async {
      await buka(tester, () => info(priority: 0));
      await tester.tap(find.text('Update Sekarang'));
      await tester.pumpAndSettle();
      expect(pasang, 1);
      expect(find.text('Update Tersedia'), findsNothing);
    });

    testWidgets('wajib: tanpa Nanti Saja, tombol kembali tidak menutup', (
      tester,
    ) async {
      await buka(tester, () => info(priority: 5));
      expect(find.text('Update Tersedia'), findsOneWidget);
      expect(find.text('Nanti Saja'), findsNothing);
      expect(find.textContaining('sudah tidak didukung'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Update Tersedia'), findsOneWidget);
    });

    testWidgets('wajib: layar Play dibatalkan → modal muncul lagi', (
      tester,
    ) async {
      hasilPasang = [AppUpdateResult.userDeniedUpdate, AppUpdateResult.success];
      await buka(tester, () => info(priority: 4));

      await tester.tap(find.text('Update Sekarang'));
      await tester.pumpAndSettle();
      expect(pasang, 1);
      expect(find.text('Update Tersedia'), findsOneWidget);

      await tester.tap(find.text('Update Sekarang'));
      await tester.pumpAndSettle();
      expect(pasang, 2);
      expect(find.text('Update Tersedia'), findsNothing);
    });

    testWidgets('update terputus dilanjutkan tanpa modal', (tester) async {
      await buka(
        tester,
        () => info(
          availability: UpdateAvailability.developerTriggeredUpdateInProgress,
        ),
      );
      expect(pasang, 1);
      expect(find.text('Update Tersedia'), findsNothing);
    });

    testWidgets('tidak ada versi baru → tidak ada modal', (tester) async {
      await buka(
        tester,
        () => info(availability: UpdateAvailability.updateNotAvailable),
      );
      expect(cek, 1);
      expect(find.text('Update Tersedia'), findsNothing);
      expect(find.text('Beranda'), findsOneWidget);
    });

    testWidgets('Play menolak (build debug / bukan dari Play) → diam', (
      tester,
    ) async {
      await buka(tester, () => throw Exception('ERROR_APP_NOT_OWNED'));
      expect(tester.takeException(), isNull);
      expect(find.text('Update Tersedia'), findsNothing);
      expect(find.text('Beranda'), findsOneWidget);
    });

    testWidgets('bukan Android → tidak memeriksa', (tester) async {
      await buka(tester, () => info(priority: 5), supported: false);
      expect(cek, 0);
      expect(find.text('Update Tersedia'), findsNothing);
    });
  });
}
