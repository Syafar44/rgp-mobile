// Pemilihan outlet terdekat otomatis saat aplikasi dibuka.
//
// Tanpa server & GPS, yang bisa diuji adalah penjaganya — dan justru itu yang
// penting: kapan fungsi ini BOLEH dan TIDAK BOLEH menyentuh lokasi pembeli.
// Cabang yang dijalankan dibaca dari AppLog.

import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/core/utils/app_log.dart';
import 'package:roti_gembung_panglima_app/data/auth_store.dart';
import 'package:roti_gembung_panglima_app/data/models/outlet.dart';
import 'package:roti_gembung_panglima_app/data/models/user_account.dart';
import 'package:roti_gembung_panglima_app/data/nearest_outlet.dart';
import 'package:roti_gembung_panglima_app/data/outlet_store.dart';

const _outlet = Outlet(
  id: 19,
  name: 'RGP Juanda 1',
  address: 'Jl. Juanda',
  distanceKm: 0.5,
);

const _user = UserAccount(
  id: '55',
  phone: '082250851457',
  name: 'Syafar',
  email: 'syafar@panglima.id',
);

/// Pesan log terakhir bertag OUTLET.
String? get _jejak => AppLog.entries
    .where((e) => e.tag == 'OUTLET')
    .map((e) => e.message)
    .firstOrNull;

void main() {
  setUp(() {
    AppLog.clear();
    outletStore.selected.value = null;
    authStore.currentUser.value = null;
  });
  tearDown(() {
    outletStore.selected.value = null;
    authStore.currentUser.value = null;
  });

  // Catatan: perilaku "menimpa outlet lama dengan yang terdekat" tidak bisa
  // diuji di sini — butuh GPS dan server sungguhan. Yang diuji adalah
  // penjaga-penjaganya, yang justru paling mudah rusak tanpa disadari.

  test('pencarian gagal: outlet lama dibiarkan, tidak dikosongkan', () async {
    // Tanpa GPS di lingkungan test, pencarian pasti gagal. Pembeli tidak boleh
    // kehilangan outletnya hanya karena lokasi tak terbaca.
    authStore.currentUser.value = _user;
    outletStore.selected.value = _outlet;

    final hasil = await autoSelectNearestOutlet();

    expect(hasil, isNull);
    expect(outletStore.outlet, _outlet);
  });

  test('belum masuk: tidak menyentuh lokasi sama sekali', () async {
    // `POST /outlets/nearby` butuh token Bearer, jadi percuma meminta izin
    // lokasi sebelum pembeli masuk.
    final hasil = await autoSelectNearestOutlet();

    expect(hasil, isNull);
    expect(outletStore.hasOutlet, isFalse);
    // Berhenti sebelum sempat mencatat "mencari outlet terdekat…".
    expect(_jejak, isNull);
  });

  test('server belum dikonfigurasi: tidak menyentuh lokasi sama sekali',
      () async {
    // `.env` tidak dimuat di lingkungan test, sama seperti aplikasi yang
    // dipasang tanpa BASE_URL. Percuma meminta izin lokasi kalau daftar
    // outletnya sendiri tidak mungkin diambil.
    authStore.currentUser.value = _user;

    final hasil = await autoSelectNearestOutlet();

    expect(hasil, isNull);
    expect(outletStore.hasOutlet, isFalse);
    expect(_jejak, isNull);
  });

  test('gagal mencari tidak pernah melempar galat ke pemanggil', () async {
    // Dipanggil saat aplikasi start; galat apa pun di sini tidak boleh
    // menggagalkan pembukaan aplikasi.
    authStore.currentUser.value = _user;
    outletStore.selected.value = null;

    await expectLater(autoSelectNearestOutlet(), completes);
  });
}
