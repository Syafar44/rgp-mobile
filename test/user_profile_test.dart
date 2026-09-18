// Kontrak parsing `GET /me` — memakai contoh respons asli dari server.

import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/data/models/user_profile.dart';

void main() {
  // Respons nyata dari API (akun customer end user hasil /register).
  const response = {
    'data': {
      'customer': ['386'],
      'department': '',
      'email': 'target44135@gmail.com',
      'email_verified': true,
      'name': 'syafar',
      'roles': 'Customer - End User',
      'userid': 59,
    },
    'message': 'success',
  };

  test('UserProfile.fromResponse membaca seluruh field /me', () {
    final profile = UserProfile.fromResponse(response);

    // `userid` datang sebagai angka, disimpan sebagai string.
    expect(profile.userId, '59');
    expect(profile.name, 'syafar');
    expect(profile.email, 'target44135@gmail.com');
    expect(profile.emailVerified, isTrue);
    expect(profile.roles, 'Customer - End User');
    expect(profile.department, '');
    expect(profile.customer, ['386']);
    expect(profile.customerId, '386');
  });

  test('email_verified yang hilang dianggap false, bukan error', () {
    final profile = UserProfile.fromResponse({
      'data': {'userid': 7, 'name': 'Budi'},
    });

    expect(profile.emailVerified, isFalse);
    expect(profile.email, '');
    expect(profile.customer, isEmpty);
    expect(profile.customerId, isNull);
  });

  test('penanda "*" tidak dianggap id customer sungguhan', () {
    final profile = UserProfile.fromResponse({
      'data': {
        'userid': 1,
        'name': 'Karyawan',
        'customer': ['*'],
      },
    });

    expect(profile.customer, ['*']);
    expect(profile.customerId, isNull);
  });

  test('body tanpa data tidak membuat parsing gagal', () {
    final profile = UserProfile.fromResponse({'message': 'success'});

    expect(profile.userId, '');
    expect(profile.name, '');
    expect(profile.emailVerified, isFalse);
  });
}
