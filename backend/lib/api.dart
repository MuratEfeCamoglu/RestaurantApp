import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'database.dart';

/// Tüm isteklere CORS başlıkları ekleyen ve OPTIONS preflight isteklerini
/// yanıtlayan middleware. Flutter web/masaüstü/mobil istemcilerin farklı
/// origin'lerden bu API'ye erişebilmesi için gereklidir.
Middleware _cors() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type',
  };
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: headers);
      }
      final response = await innerHandler(request);
      return response.change(headers: headers);
    };
  };
}

Response _json(Object? data, {int status = 200}) {
  return Response(
    status,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json; charset=utf-8'},
  );
}

/// URL'deki `<id>` parçasını sayıya çevirir; sayı değilse "Geçersiz JSON"
/// yerine anlaşılır bir 400 hatası döndürmek için [ApiError] fırlatır.
int _idOf(String raw) {
  final id = int.tryParse(raw);
  if (id == null) throw ApiError('Geçersiz id: $raw');
  return id;
}

Future<Map<String, Object?>> _bodyOf(Request request) async {
  final raw = await request.readAsString();
  if (raw.trim().isEmpty) return {};
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, Object?>) {
    throw ApiError('Geçersiz istek gövdesi.');
  }
  return decoded;
}

/// Uygulamanın tüm REST API'sini kuran router. `db` ile konuşur, HTTP
/// katmanına özgü tek iş: gövdeyi çözmek, sonucu JSON'a çevirmek ve
/// [ApiError]'ları uygun HTTP durum koduna eşlemek.
Handler buildApiHandler(RestaurantDb db) {
  final router = Router();

  router.get('/api/health', (Request req) => _json({'status': 'ok'}));

  router.get('/api/bootstrap', (Request req) => _json(db.bootstrap()));

  // ---- Areas --------------------------------------------------------------

  router.get('/api/areas', (Request req) => _json(db.listAreas()));

  router.post('/api/areas', (Request req) async {
    final body = await _bodyOf(req);
    final name = body['name'] as String? ?? '';
    return _json(db.createArea(name), status: 201);
  });

  // ---- Tables ---------------------------------------------------------------

  router.get('/api/tables', (Request req) => _json(db.listTables()));

  router.post('/api/tables', (Request req) async {
    final body = await _bodyOf(req);
    final name = body['name'] as String? ?? '';
    final areaId = body['areaId'];
    if (areaId is! int) throw ApiError('areaId zorunludur.');
    return _json(db.createTable(name, areaId), status: 201);
  });

  router.put('/api/tables/<id>', (Request req, String id) async {
    final body = await _bodyOf(req);
    return _json(db.updateTable(
      _idOf(id),
      name: body['name'] as String?,
      areaId: body['areaId'] as int?,
    ));
  });

  router.delete('/api/tables/<id>', (Request req, String id) {
    db.deleteTable(_idOf(id));
    return Response(204);
  });

  router.post('/api/tables/<id>/open', (Request req, String id) async {
    final body = await _bodyOf(req);
    return _json(db.openTable(_idOf(id), guests: body['guests'] as int?));
  });

  router.post('/api/tables/<id>/request-bill', (Request req, String id) {
    return _json(db.requestBill(_idOf(id)));
  });

  router.post('/api/tables/<id>/settle', (Request req, String id) {
    return _json(db.settleBill(_idOf(id)));
  });

  router.get('/api/tables/<id>/bill', (Request req, String id) {
    return _json(db.billForTable(_idOf(id)));
  });

  // ---- Menu -----------------------------------------------------------------

  router.get('/api/menu', (Request req) => _json(db.listMenu()));

  // ---- Orders ---------------------------------------------------------------

  router.post('/api/orders', (Request req) async {
    final body = await _bodyOf(req);
    final tableId = body['tableId'];
    final items = body['items'];
    if (tableId is! int) throw ApiError('tableId zorunludur.');
    if (items is! List) throw ApiError('items bir liste olmalı.');
    final normalized = items.cast<Map<String, Object?>>();
    return _json(db.createOrder(tableId, normalized), status: 201);
  });

  router.post('/api/orders/<id>/served', (Request req, String id) {
    return _json(db.markOrderServed(_idOf(id)));
  });

  // ---- Mutfak ---------------------------------------------------------------

  router.get('/api/kitchen', (Request req) => _json(db.kitchenQueue()));

  router.all('/<ignored|.*>', (Request req) => _json({'error': 'Bulunamadı: ${req.url.path}'}, status: 404));

  final pipeline = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addMiddleware(_errorHandler())
      .addHandler(router.call);

  return pipeline;
}

Middleware _errorHandler() {
  return (Handler innerHandler) {
    return (Request request) async {
      try {
        return await innerHandler(request);
      } on ApiError catch (e) {
        return _json({'error': e.message}, status: e.statusCode);
      } on FormatException catch (e) {
        return _json({'error': 'Geçersiz JSON: ${e.message}'}, status: 400);
      } on TypeError {
        // Gövdedeki alanın tipi yanlışsa (örn. areaId: "x") `as int?` gibi
        // dönüşümler TypeError fırlatır; bu sunucu hatası değil, kötü istektir.
        return _json({'error': 'Geçersiz istek: alan tipleri hatalı.'}, status: 400);
      } catch (e) {
        return _json({'error': 'Sunucu hatası: $e'}, status: 500);
      }
    };
  };
}
