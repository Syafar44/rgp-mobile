// Kontrak parsing menu outlet — memakai contoh respons dari dokumen
// "API Aplikasi Customer" bagian 2 (Menu & harga outlet).

import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/data/api/menu_api.dart';
import 'package:roti_gembung_panglima_app/data/menu_repository.dart';
import 'package:dio/dio.dart';

void main() {
  // Parser tidak menyentuh jaringan, jadi Dio kosong sudah cukup.
  final repo = MenuRepository(MenuApi(Dio()));

  const response = {
    'message': 'Success',
    'data': [
      {
        'category_id': 3,
        'category': 'Roti Manis',
        'data': [
          {
            'id': 101,
            'code': 'RM-001',
            'title': 'Roti Coklat',
            'menu_type': 'regular',
            'price': 12000,
            'image_url':
                'https://erp.example.com/storage/menus/roti-coklat.jpg',
          },
          {
            'id': 150,
            'code': 'PKT-01',
            'title': 'Paket Hemat 3',
            'menu_type': 'package',
            'price': 30000,
            'image_url': null,
            'max_qty': 3,
            'props': [
              {'id': 101, 'code': 'RM-001', 'title': 'Roti Coklat'},
              {'id': 102, 'code': 'RM-002', 'title': 'Roti Keju'},
            ],
          },
        ],
      },
      {
        'category_id': 7,
        'category': 'Es Krim',
        'data': [
          {
            'id': 220,
            'code': 'EK-001',
            'title': 'Es Krim Vanila',
            'menu_type': 'regular',
            'price': 8000,
          },
        ],
      },
    ],
  };

  test('menu biasa dibaca lengkap beserta kategorinya', () {
    final menus = repo.parseMenus(response);

    expect(menus, hasLength(3));
    final roti = menus.first;
    expect(roti.id, '101');
    expect(roti.code, 'RM-001');
    expect(roti.name, 'Roti Coklat');
    expect(roti.price, 12000);
    expect(roti.category, 'Roti Manis');
    expect(roti.categoryId, 3);
    expect(roti.isPackage, isFalse);
    expect(roti.imageUrl, isNotNull);
  });

  test('paket membawa max_qty & daftar varian untuk dipilih', () {
    final paket = repo.parseMenus(response)[1];

    expect(paket.isPackage, isTrue);
    expect(paket.maxQty, 3);
    expect(paket.variants, hasLength(2));
    expect(paket.variants.first.id, 101);
    expect(paket.variants.first.title, 'Roti Coklat');
    // image_url boleh null.
    expect(paket.imageUrl, isNull);
  });

  test('kategori mewarisi ke menu walau item tidak mengulang category_id', () {
    final esKrim = repo.parseMenus(response).last;

    expect(esKrim.category, 'Es Krim');
    expect(esKrim.categoryId, 7);
  });

  test('body tanpa data menghasilkan daftar kosong, bukan exception', () {
    expect(repo.parseMenus({'message': 'Success'}), isEmpty);
    expect(repo.parseMenus(null), isEmpty);
  });
}
