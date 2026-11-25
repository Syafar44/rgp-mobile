import 'package:flutter/material.dart';

/// Index halaman aktif pada [WidgetTree] / bottom navigation.
///
/// 0=Beranda, 1=Menu, 2=VIP, 3=History, 4=Profile.
/// Halaman mana pun bisa berpindah tab dengan mengubah `.value`.
final ValueNotifier<int> selectedPageNotifier = ValueNotifier<int>(0);

/// Index tab Menu — tujuan tombol "Order" di Beranda.
const int menuTabIndex = 1;

/// Index tab Pesanan — diberi nama supaya perpindahan dari luar (mis. ketukan
/// notifikasi) tidak menaruh angka ajaib di tempat lain.
const int ordersTabIndex = 3;
