import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roti_gembung_panglima_app/app.dart';
import 'package:roti_gembung_panglima_app/data/auth_store.dart';
import 'package:roti_gembung_panglima_app/data/cart_store.dart';
import 'package:roti_gembung_panglima_app/data/models/cart.dart';
import 'package:roti_gembung_panglima_app/data/models/outlet.dart';
import 'package:roti_gembung_panglima_app/data/models/user_account.dart';
import 'package:roti_gembung_panglima_app/data/outlet_store.dart';

void main() {
  testWidgets('dbg3', (tester) async {
    authStore.currentUser.value = const UserAccount(
        id: '55', phone: '0', name: 'S', email: 's@p.id', emailVerified: true);
    outletStore.selected.value = const Outlet(
        id: 19, name: 'RGP', address: 'Jl', distanceKm: 0.5);
    cartStore.cart.value = const ServerCart(outletId: 19, items: [
      ServerCartItem(id: 1, menuId: 586, title: 'Roti', menuType: 'single',
          quantity: 1, price: 8000, subtotal: 8000)
    ], total: 8000);

    await tester.pumpWidget(const RotiGembungApp());
    await tester.pumpAndSettle();
    debugPrint('Scrollable sebelum tap Profile: ${find.byType(Scrollable).evaluate().length}');
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    debugPrint('Scrollable sesudah tap Profile: ${find.byType(Scrollable).evaluate().length}');
    debugPrint('Hapus Akun ketemu: ${find.text('Hapus Akun').evaluate().length}');
    for (final w in find.byType(Text).evaluate().take(30)) {
      debugPrint('TEXT: ${(w.widget as Text).data}');
    }
  });
}
