import 'dart:convert';
import 'dart:io';

import 'package:addisyonapp/api_client.dart';
import 'package:addisyonapp/screens/salon_screen.dart';
import 'package:addisyonapp/state.dart';
import 'package:addisyonapp/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

Map<String, Object?> table(int id, String status, {int bill = 0}) => {
      'id': id,
      'name': 'Masa $id',
      'areaId': 1,
      'areaName': 'Salon',
      'status': status,
      'statusLabel': null,
      'guests': status == 'available' ? 0 : 2,
      'openedAt': status == 'available' ? null : DateTime.now().toIso8601String(),
      'billTotal': bill,
    };

Future<void> _loadFont(String family, String file) async {
  // Windows dışında yazı tipi yoksa varsayılan test fontuyla devam edilir.
  final f = File('C:/Windows/Fonts/$file');
  if (!f.existsSync()) return;
  final bytes = await f.readAsBytes();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    await _loadFont('WorkSans_regular', 'segoeui.ttf');
    await _loadFont('WorkSans_600', 'segoeuisl.ttf');
    await _loadFont('WorkSans_700', 'segoeuib.ttf');
    await _loadFont('Domine_600', 'georgiab.ttf');
  });

  for (final size in [const Size(320, 568), const Size(360, 740), const Size(412, 915)]) {
    testWidgets('akış ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final tables = {1: table(1, 'available'), 2: table(2, 'billPending', bill: 1234), 3: table(3, 'occupied', bill: 5)};
      final client = MockClient((req) async {
        final path = req.url.path;
        Object? out;
        if (path == '/api/bootstrap') {
          out = {
            'areas': [
              {'id': 1, 'name': 'Salon'}
            ],
            'tables': tables.values.toList(),
            'menu': [
              for (var i = 0; i < 6; i++)
                {
                  'id': 'm$i',
                  'name': 'Çok uzun isimli bir ürün adı numara $i',
                  'price': 1250 + i,
                  'category': 'Ana Yemekler',
                  'popular': i < 3,
                  'description': 'Açıklama',
                  'tags': ['a', 'b'],
                  'stripeA': 0xFFEEDDCC,
                  'stripeB': 0xFFDDCCBB,
                }
            ],
            'categories': ['Popüler', 'Başlangıçlar', 'Salatalar', 'Ana Yemekler', 'Pizza', 'Tatlılar'],
          };
        } else if (path.endsWith('/open')) {
          final id = int.parse(path.split('/')[3]);
          tables[id] = table(id, 'occupied');
          out = tables[id];
        } else if (path.endsWith('/bill')) {
          final id = int.parse(path.split('/')[3]);
          out = {'table': tables[id], 'items': [], 'subtotal': 0, 'serviceFee': 0, 'total': 0};
        } else if (path.endsWith('/request-bill')) {
          final id = int.parse(path.split('/')[3]);
          tables[id] = table(id, 'billPending');
          out = tables[id];
        } else if (path == '/api/kitchen') {
          out = [];
        } else if (path.endsWith('/settle')) {
          final id = int.parse(path.split('/')[3]);
          tables[id] = table(id, 'available');
          out = tables[id];
        } else if (path == '/api/orders') {
          out = {
            'orderNumber': 4822,
            'table': tables[1],
            'itemCount': 2,
            'subtotal': 2500,
            'serviceFee': 250,
            'total': 2750,
          };
        }
        return http.Response.bytes(utf8.encode(jsonEncode(out)), 200, headers: {'content-type': 'application/json'});
      });

      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => RestaurantState(apiClient: ApiClient(httpClient: client)),
        child: MaterialApp(theme: buildAppTheme(), home: const SalonScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Masa 1'), findsOneWidget);

      // Masa seçmeden de menü görülebilir.
      await tester.tap(find.text('Menü'));
      await tester.pumpAndSettle();
      expect(find.text('Masa seçmeden menüye göz atabilirsiniz'), findsOneWidget);
      expect(find.text('Menüde ara'), findsOneWidget);

      // Mutfak sekmesi: hazırlanan sipariş yokken boş durum.
      await tester.tap(find.text('Mutfak'));
      await tester.pumpAndSettle();
      expect(find.text('Mutfakta bekleyen sipariş yok'), findsOneWidget);
      await tester.tap(find.text('Salon'));
      await tester.pumpAndSettle();

      // Boş masa aç -> menü
      await tester.tap(find.text('Masa 1'));
      await tester.pumpAndSettle();
      expect(find.text('AKTİF SİPARİŞ'), findsOneWidget);

      // Sepete ekle, sepete git
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sepeti Gör'));
      await tester.pumpAndSettle();
      expect(find.text('Sepetiniz'), findsOneWidget);
      await tester.tap(find.text('Siparişi Gönder'));
      await tester.pumpAndSettle();
      expect(find.text('Sipariş Mutfağa İletildi'), findsOneWidget);

      // Siparişi görüntüle -> hesap detayı
      await tester.tap(find.text('Siparişi Görüntüle'));
      await tester.pumpAndSettle();
      expect(find.text('HESAP DETAYI'), findsOneWidget);
      // Hesap istenmeden ödeme/kapatma yok.
      expect(find.text('Masayı Kapat'), findsNothing);
      expect(find.text('Ödemeyi Al'), findsNothing);
      await tester.tap(find.text('Hesap İste'));
      await tester.pumpAndSettle();
      expect(find.text('Masayı Kapat'), findsOneWidget);
      await tester.tap(find.text('Masayı Kapat'));
      await tester.pumpAndSettle();
      expect(find.text('HESAP DETAYI'), findsNothing);

      // Hesaplar sekmesi
      await tester.tap(find.text('Hesaplar'));
      await tester.pumpAndSettle();
      expect(find.text('Açık Hesaplar'), findsOneWidget);
    });
  }
}
