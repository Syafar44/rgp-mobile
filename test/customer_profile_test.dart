// Kontrak parsing `GET /customer/me` & `PATCH /customer/profile` — memakai
// contoh respons dari dokumen "API Profil Customer End User".
//
// Data kontak & alamat sengaja dipisahkan server dari `GET /me`, jadi model
// ini yang menjadi sumber nomor HP di aplikasi.

import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/data/models/customer_profile.dart';

void main() {
  const response = {
    'id': 3,
    'name': 'Budi Santoso',
    'email': 'budi@example.com',
    'contact': '081234567890',
    'address': 'Jl. Melati No. 10, Bandung',
    'code': 'CUS1788585593655',
    'customer_groups_id': 1,
    'is_active': true,
  };

  test('membaca seluruh field profil customer', () {
    final profile = CustomerProfile.fromJson(response);

    // `id` adalah id baris customers, bukan id user.
    expect(profile.id, 3);
    expect(profile.name, 'Budi Santoso');
    expect(profile.email, 'budi@example.com');
    expect(profile.contact, '081234567890');
    expect(profile.address, 'Jl. Melati No. 10, Bandung');
    expect(profile.code, 'CUS1788585593655');
    expect(profile.customerGroupsId, 1);
    expect(profile.isActive, isTrue);
  });

  test('balasan PATCH berbentuk sama, jadi bisa dipakai langsung', () {
    final updated = CustomerProfile.fromJson({
      ...response,
      'contact': '089999999999',
      'address': 'Jl. Melati No. 12, Bandung',
    });

    expect(updated.contact, '089999999999');
    expect(updated.address, 'Jl. Melati No. 12, Bandung');
    // Field yang tidak diubah tetap utuh.
    expect(updated.code, 'CUS1788585593655');
  });

  test('field yang hilang tidak membuat parsing gagal', () {
    final profile = CustomerProfile.fromJson({'id': 9, 'name': 'Tanpa Kontak'});

    expect(profile.contact, '');
    expect(profile.address, '');
    expect(profile.code, '');
    // Tidak ada `is_active` dianggap aktif.
    expect(profile.isActive, isTrue);
  });

  test('is_active false terbaca sebagai nonaktif', () {
    final profile = CustomerProfile.fromJson({...response, 'is_active': false});

    expect(profile.isActive, isFalse);
  });
}
