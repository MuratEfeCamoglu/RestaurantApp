// Basic smoke test: the app boots, loads data from the backend (mocked
// here so the test doesn't depend on a running server) and shows the
// Salon screen.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:addisyonapp/api_client.dart';
import 'package:addisyonapp/screens/salon_screen.dart';
import 'package:addisyonapp/state.dart';
import 'package:addisyonapp/theme.dart';

const _bootstrapJson = {
  'areas': [
    {'id': 1, 'name': 'Teras', 'sortOrder': 0},
  ],
  'tables': [
    {
      'id': 1,
      'name': 'Masa 1',
      'areaId': 1,
      'areaName': 'Teras',
      'status': 'available',
      'statusLabel': null,
      'guests': 0,
      'openedAt': null,
      'billTotal': 0,
    },
  ],
  'menu': [
    {
      'id': 'ayran',
      'name': 'Ayran',
      'price': 95,
      'category': 'İçecekler',
      'popular': false,
      'description': '',
      'tags': <String>[],
      'stripeA': 0xFFDCE6E0,
      'stripeB': 0xFFE8EFEA,
    },
  ],
  'categories': ['Popüler', 'İçecekler'],
};

ApiClient _mockApiClient() {
  final client = MockClient((request) async {
    if (request.url.path == '/api/bootstrap') {
      return http.Response(jsonEncode(_bootstrapJson), 200, headers: {'content-type': 'application/json'});
    }
    return http.Response(jsonEncode({'error': 'not stubbed'}), 404);
  });
  return ApiClient(baseUrl: 'http://test.local', httpClient: client);
}

void main() {
  testWidgets('App boots and shows Salon screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => RestaurantState(apiClient: _mockApiClient()),
        child: MaterialApp(theme: buildAppTheme(), home: const SalonScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Salon screen header text should be visible once data has loaded.
    expect(find.text('Akşam Servisi'), findsOneWidget);
    // Bottom navigation should show all three tabs.
    expect(find.text('Salon'), findsOneWidget);
    expect(find.text('Menü'), findsOneWidget);
    expect(find.text('Hesaplar'), findsOneWidget);
    // Seeded table from the mocked backend should render.
    expect(find.text('Masa 1'), findsOneWidget);
  });
}
