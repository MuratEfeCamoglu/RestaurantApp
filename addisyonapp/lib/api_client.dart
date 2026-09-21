import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Backend'e ulaşılamadığında ya da backend bir hata döndürdüğünde
/// fırlatılır. `message` kullanıcıya doğrudan gösterilebilecek Türkçe bir
/// mesajdır.
class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class Bootstrap {
  Bootstrap({required this.areas, required this.tables, required this.menu, required this.categories});

  final List<RestaurantArea> areas;
  final List<RestaurantTable> tables;
  final List<MenuItem> menu;
  final List<String> categories;
}

/// `backend/` klasöründeki Dart (shelf) REST API'siyle konuşan istemci.
///
/// Varsayılan adres masaüstü/web/Android emülatöründe otomatik doğru
/// değere düşer. Gerçek bir telefondan test ederken bilgisayarınızın LAN
/// IP'sini vermeniz gerekir:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080`
class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
      : baseUrl = baseUrl ?? _defaultBaseUrl(),
        _client = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 10);

  static String _defaultBaseUrl() {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    // Android emülatörde `localhost` emülatörün kendisini gösterir; ana
    // makineye ulaşmak için özel `10.0.2.2` adresi kullanılır.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, Object?> _asMap(Object? decoded) {
    if (decoded is Map<String, Object?>) return decoded;
    throw ApiException('Sunucudan beklenmeyen bir yanıt geldi.');
  }

  List<Object?> _asList(Object? decoded) {
    if (decoded is List<Object?>) return decoded;
    throw ApiException('Sunucudan beklenmeyen bir yanıt geldi.');
  }

  Future<dynamic> _send(String method, String path, {Map<String, Object?>? body}) async {
    try {
      final uri = _uri(path);
      final headers = {'Content-Type': 'application/json; charset=utf-8'};
      late http.Response response;
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(_timeout);
          break;
        case 'POST':
          response = await _client.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(_timeout);
          break;
        case 'PUT':
          response = await _client.put(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(_timeout);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers).timeout(_timeout);
          break;
        default:
          throw ArgumentError('Bilinmeyen metod: $method');
      }

      if (response.statusCode == 204 || response.body.isEmpty) {
        if (response.statusCode >= 400) {
          throw ApiException('Sunucu hatası (${response.statusCode}).');
        }
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 400) {
        final message = decoded is Map && decoded['error'] != null
            ? decoded['error'] as String
            : 'Sunucu hatası (${response.statusCode}).';
        throw ApiException(message);
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Sunucudan yanıt alınamadı (zaman aşımı). Backend çalışıyor mu?');
    } on SocketException {
      throw ApiException('Sunucuya bağlanılamadı. Backend çalışıyor mu? ($baseUrl)');
    } catch (e) {
      throw ApiException('Beklenmeyen bir hata oluştu: $e');
    }
  }

  // ---- Bootstrap ------------------------------------------------------------

  Future<Bootstrap> fetchBootstrap() async {
    final json = _asMap(await _send('GET', '/api/bootstrap'));
    return Bootstrap(
      areas: _asList(json['areas'])
          .map((e) => RestaurantArea.fromJson(e as Map<String, dynamic>))
          .toList(),
      tables: _asList(json['tables'])
          .map((e) => RestaurantTable.fromJson(e as Map<String, dynamic>))
          .toList(),
      menu: _asList(json['menu']).map((e) => MenuItem.fromJson(e as Map<String, dynamic>)).toList(),
      categories: _asList(json['categories']).cast<String>(),
    );
  }

  // ---- Areas ------------------------------------------------------------------

  Future<RestaurantArea> createArea(String name) async {
    final json = _asMap(await _send('POST', '/api/areas', body: {'name': name}));
    return RestaurantArea.fromJson(json);
  }

  // ---- Tables -------------------------------------------------------------------

  Future<RestaurantTable> createTable({required String name, required int areaId}) async {
    final json = _asMap(await _send('POST', '/api/tables', body: {'name': name, 'areaId': areaId}));
    return RestaurantTable.fromJson(json);
  }

  Future<RestaurantTable> updateTable(int id, {String? name, int? areaId}) async {
    final json = _asMap(await _send('PUT', '/api/tables/$id', body: {
      if (name != null) 'name': name,
      if (areaId != null) 'areaId': areaId,
    }));
    return RestaurantTable.fromJson(json);
  }

  Future<void> deleteTable(int id) => _send('DELETE', '/api/tables/$id');

  Future<RestaurantTable> openTable(int id, {int? guests}) async {
    final json = _asMap(await _send('POST', '/api/tables/$id/open', body: {if (guests != null) 'guests': guests}));
    return RestaurantTable.fromJson(json);
  }

  Future<RestaurantTable> requestBill(int id) async {
    final json = _asMap(await _send('POST', '/api/tables/$id/request-bill'));
    return RestaurantTable.fromJson(json);
  }

  Future<RestaurantTable> settleBill(int id) async {
    final json = _asMap(await _send('POST', '/api/tables/$id/settle'));
    return RestaurantTable.fromJson(json);
  }

  Future<BillDetail> fetchBill(int id) async {
    final json = _asMap(await _send('GET', '/api/tables/$id/bill'));
    return BillDetail.fromJson(json);
  }

  // ---- Orders ---------------------------------------------------------------------

  Future<SubmittedOrder> submitOrder({required int tableId, required List<CartItem> items}) async {
    final json = _asMap(await _send('POST', '/api/orders', body: {
      'tableId': tableId,
      'items': [
        for (final ci in items) {'menuItemId': ci.item.id, 'qty': ci.qty, 'note': ci.note},
      ],
    }));
    return SubmittedOrder(
      orderNumber: json['orderNumber'] as int,
      table: RestaurantTable.fromJson(json['table'] as Map<String, dynamic>),
      itemCount: json['itemCount'] as int,
      subtotal: json['subtotal'] as int,
      serviceFee: json['serviceFee'] as int,
      total: json['total'] as int,
    );
  }

  // ---- Mutfak ---------------------------------------------------------------------

  Future<List<KitchenTicket>> fetchKitchen() async {
    final json = _asList(await _send('GET', '/api/kitchen'));
    return json.map((e) => KitchenTicket.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RestaurantTable> markOrderServed(int orderId) async {
    final json = _asMap(await _send('POST', '/api/orders/$orderId/served'));
    return RestaurantTable.fromJson(json['table'] as Map<String, dynamic>);
  }
}
