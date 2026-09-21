import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/salon_screen.dart';
import 'state.dart';
import 'theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RestaurantState(),
      child: MaterialApp(
        title: 'Limon & Zeytin — Sipariş Yönetimi',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const SalonScreen(),
      ),
    );
  }
}
