// Tulisan "Versi Aplikasi" dibaca dari paket, bukan ditulis tangan.

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:roti_gembung_panglima_app/core/utils/app_version.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('format: versionName (versionCode)', () {
    expect(AppVersion.format('1.0.2', '4'), '1.0.2 (4)');
    expect(AppVersion.format('1.0.2', ''), '1.0.2');
    expect(AppVersion.format('', '4'), '');
  });

  test('dimuat dari info paket (= version: di pubspec)', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Roti Gembung Panglima',
      packageName: 'com.panglima.roti_gembung_panglima_app',
      version: '1.0.2',
      buildNumber: '4',
      buildSignature: '',
    );
    await AppVersion.load();
    expect(AppVersion.label, '1.0.2 (4)');
  });
}
