import 'package:flutter/material.dart';

import 'screens/bill_list_screen.dart';
import 'screens/kitchen_screen.dart';
import 'screens/menu_screen.dart';

/// Alt gezinme çubuğundaki sekme sırası (bkz. `AppBottomNav`).
class AppTab {
  static const salon = 0;
  static const menu = 1;
  static const kitchen = 2;
  static const bills = 3;
}

/// Alt çubuktan bir sekmeye geçer. Salon kök ekrandır; diğer sekmeler onun
/// üstüne açılır. Sekmeler arası geçişte yığın büyümesin diye önce kök
/// ekrana dönülür.
void goToTab(BuildContext context, {required int current, required int target}) {
  if (target == current) return;
  final navigator = Navigator.of(context);
  navigator.popUntil((route) => route.isFirst);
  switch (target) {
    case AppTab.salon:
      return;
    case AppTab.menu:
      navigator.push(MaterialPageRoute(builder: (_) => const MenuScreen()));
    case AppTab.kitchen:
      navigator.push(MaterialPageRoute(builder: (_) => const KitchenScreen()));
    case AppTab.bills:
      navigator.push(MaterialPageRoute(builder: (_) => const BillListScreen()));
  }
}
