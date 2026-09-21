
import 'package:sqlite3/sqlite3.dart';

import 'seed_data.dart';

/// Uygulama içinde döndürülen tek bir hata türü; `api.dart` bunu HTTP durum
/// koduna çevirir.
class ApiError implements Exception {
  ApiError(this.message, {this.statusCode = 400});
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

/// Tüm veritabanı erişimini tek bir yerde toplayan repository. `sqlite3`
/// senkron çalıştığı ve bu sunucu tek bir isolate'te istekleri sırayla
/// işlediği için ek bir kilitleme mekanizmasına gerek yok.
class RestaurantDb {
  RestaurantDb(this._db) {
    _createSchema();
    _seedIfEmpty();
  }

  factory RestaurantDb.open(String path) => RestaurantDb(sqlite3.open(path));

  final Database _db;

  void close() => _db.dispose();

  void _createSchema() {
    _db.execute('''
      PRAGMA foreign_keys = ON;

      CREATE TABLE IF NOT EXISTS areas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS tables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        area_id INTEGER NOT NULL REFERENCES areas(id) ON DELETE CASCADE,
        status TEXT NOT NULL DEFAULT 'available',
        status_label TEXT,
        guests INTEGER NOT NULL DEFAULT 0,
        opened_at TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS menu_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        category TEXT NOT NULL,
        popular INTEGER NOT NULL DEFAULT 0,
        description TEXT NOT NULL DEFAULT '',
        tags TEXT NOT NULL DEFAULT '',
        stripe_a INTEGER NOT NULL,
        stripe_b INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number INTEGER NOT NULL,
        table_id INTEGER NOT NULL REFERENCES tables(id) ON DELETE CASCADE,
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
        menu_item_id TEXT NOT NULL REFERENCES menu_items(id),
        name TEXT NOT NULL,
        qty INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        unit_price INTEGER NOT NULL
      );
    ''');

    // Sipariş durumu (mutfak takibi) sonradan eklendi: mevcut veritabanlarındaki
    // eski siparişler zaten servis edilmiş sayılır ('served'), yeni siparişler
    // mutfağa 'preparing' olarak düşer (bkz. createOrder).
    final orderColumns = _db.select('PRAGMA table_info(orders)');
    if (!orderColumns.any((c) => c['name'] == 'status')) {
      _db.execute("ALTER TABLE orders ADD COLUMN status TEXT NOT NULL DEFAULT 'served'");
    }
  }

  void _seedIfEmpty() {
    final hasAreas = _db.select('SELECT COUNT(*) AS c FROM areas').first['c'] as int;
    if (hasAreas == 0) {
      var tableNumber = 1;
      for (var areaIndex = 0; areaIndex < seedAreas.length; areaIndex++) {
        final area = seedAreas[areaIndex];
        _db.execute('INSERT INTO areas (name, sort_order) VALUES (?, ?)', [area.name, areaIndex]);
        final areaId = _db.lastInsertRowId;
        for (var i = 0; i < area.tableCount; i++) {
          // Tüm masalar müsait başlar; bir masa yalnızca uygulama içinden
          // gerçekten açıldığında (bkz. openTable) dolu/hesap bekliyor
          // durumuna geçer ve Hesaplar ekranında görünür.
          _db.execute(
            "INSERT INTO tables (name, area_id, status, guests, opened_at, sort_order) "
            "VALUES (?, ?, 'available', 0, NULL, ?)",
            ['Masa $tableNumber', areaId, i],
          );
          tableNumber++;
        }
      }
    }

    // Menü listesine yeni ürün eklendiğinde mevcut veritabanları da otomatik
    // güncellensin diye bu, tablo boş olsa da olmasa da her açılışta
    // çalışır; zaten var olan ürünler INSERT OR IGNORE ile atlanır.
    for (var i = 0; i < seedMenuItems.length; i++) {
      final item = seedMenuItems[i];
      _db.execute(
        'INSERT OR IGNORE INTO menu_items (id, name, price, category, popular, description, tags, stripe_a, stripe_b, sort_order) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          item.id,
          item.name,
          item.price,
          item.category,
          item.popular ? 1 : 0,
          item.description,
          item.tags.join('|'),
          item.stripeA,
          item.stripeB,
          i,
        ],
      );
    }
  }

  // ---- Areas ------------------------------------------------------------

  List<Map<String, Object?>> listAreas() {
    return _db
        .select('SELECT id, name, sort_order AS sortOrder FROM areas ORDER BY sort_order, id')
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  Map<String, Object?> createArea(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ApiError('Alan adı boş olamaz.');
    final maxOrder = (_db.select('SELECT COALESCE(MAX(sort_order), -1) AS m FROM areas').first['m'] as int) + 1;
    try {
      _db.execute('INSERT INTO areas (name, sort_order) VALUES (?, ?)', [trimmed, maxOrder]);
    } on SqliteException {
      throw ApiError('Bu isimde bir alan zaten var.', statusCode: 409);
    }
    final id = _db.lastInsertRowId;
    return {'id': id, 'name': trimmed, 'sortOrder': maxOrder};
  }

  // ---- Tables -------------------------------------------------------------

  static const _tableSelect = '''
    SELECT
      t.id AS id,
      t.name AS name,
      t.area_id AS areaId,
      a.name AS areaName,
      t.status AS status,
      t.status_label AS statusLabel,
      t.guests AS guests,
      t.opened_at AS openedAt,
      COALESCE((
        SELECT SUM(oi.qty * oi.unit_price)
        FROM order_items oi
        JOIN orders o ON o.id = oi.order_id
        WHERE o.table_id = t.id AND t.opened_at IS NOT NULL AND o.created_at >= t.opened_at
      ), 0) AS billTotal,
      (
        SELECT COUNT(*)
        FROM orders o
        WHERE o.table_id = t.id AND o.status = 'preparing'
          AND t.opened_at IS NOT NULL AND o.created_at >= t.opened_at
      ) AS kitchenCount
    FROM tables t
    JOIN areas a ON a.id = t.area_id
  ''';

  List<Map<String, Object?>> listTables() {
    return _db
        .select('$_tableSelect ORDER BY a.sort_order, t.sort_order, t.id')
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  Map<String, Object?> _getTableRow(int id) {
    final rows = _db.select('$_tableSelect WHERE t.id = ?', [id]);
    if (rows.isEmpty) throw ApiError('Masa bulunamadı.', statusCode: 404);
    return Map<String, Object?>.from(rows.first);
  }

  Map<String, Object?> createTable(String name, int areaId) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ApiError('Masa adı boş olamaz.');
    final areaExists = _db.select('SELECT 1 FROM areas WHERE id = ?', [areaId]);
    if (areaExists.isEmpty) throw ApiError('Alan bulunamadı.', statusCode: 404);
    final maxOrder =
        (_db.select('SELECT COALESCE(MAX(sort_order), -1) AS m FROM tables WHERE area_id = ?', [areaId]).first['m']
                as int) +
            1;
    _db.execute(
      "INSERT INTO tables (name, area_id, status, sort_order) VALUES (?, ?, 'available', ?)",
      [trimmed, areaId, maxOrder],
    );
    return _getTableRow(_db.lastInsertRowId);
  }

  Map<String, Object?> updateTable(int id, {String? name, int? areaId}) {
    _getTableRow(id); // 404 doğrulaması
    if (name != null) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) throw ApiError('Masa adı boş olamaz.');
      _db.execute('UPDATE tables SET name = ? WHERE id = ?', [trimmed, id]);
    }
    if (areaId != null) {
      final areaExists = _db.select('SELECT 1 FROM areas WHERE id = ?', [areaId]);
      if (areaExists.isEmpty) throw ApiError('Alan bulunamadı.', statusCode: 404);
      _db.execute('UPDATE tables SET area_id = ? WHERE id = ?', [areaId, id]);
    }
    return _getTableRow(id);
  }

  void deleteTable(int id) {
    final row = _getTableRow(id);
    if (row['status'] != 'available' && row['status'] != 'empty') {
      throw ApiError('Açık hesabı olan bir masa silinemez. Önce hesabı kapatın.', statusCode: 409);
    }
    _db.execute('DELETE FROM tables WHERE id = ?', [id]);
  }

  Map<String, Object?> openTable(int id, {int? guests}) {
    final row = _getTableRow(id);
    if (row['status'] == 'occupied' || row['status'] == 'billPending') {
      return row; // zaten açık, olduğu gibi döndür (idempotent)
    }
    final g = guests ?? 2;
    _db.execute(
      "UPDATE tables SET status = 'occupied', status_label = NULL, guests = ?, opened_at = ? WHERE id = ?",
      [g, DateTime.now().toIso8601String(), id],
    );
    return _getTableRow(id);
  }

  Map<String, Object?> requestBill(int id) {
    final row = _getTableRow(id);
    if (row['status'] != 'occupied') {
      throw ApiError('Sadece dolu bir masa için hesap istenebilir.', statusCode: 409);
    }
    _db.execute("UPDATE tables SET status = 'billPending' WHERE id = ?", [id]);
    return _getTableRow(id);
  }

  Map<String, Object?> settleBill(int id) {
    final row = _getTableRow(id);
    // Döngü: Masa → Mutfak → Hesap → Ödeme. Hesap istenmemiş bir masadan
    // ödeme alınamaz.
    if (row['status'] != 'billPending') {
      throw ApiError('Ödeme almadan önce hesap istenmeli.', statusCode: 409);
    }
    _db.execute(
      "UPDATE orders SET status = 'served' WHERE table_id = ? AND status = 'preparing'",
      [id],
    );
    _db.execute(
      "UPDATE tables SET status = 'available', status_label = NULL, guests = 0, opened_at = ? WHERE id = ?",
      [DateTime.now().toIso8601String(), id],
    );
    return _getTableRow(id);
  }

  Map<String, Object?> billForTable(int id) {
    final table = _getTableRow(id);
    final openedAt = table['openedAt'];
    final items = openedAt == null
        ? const <Map<String, Object?>>[]
        : _db.select(
            '''
            SELECT oi.menu_item_id AS menuItemId, oi.name AS name, SUM(oi.qty) AS qty,
                   oi.unit_price AS unitPrice, oi.note AS note,
                   SUM(oi.qty * oi.unit_price) AS lineTotal
            FROM order_items oi
            JOIN orders o ON o.id = oi.order_id
            WHERE o.table_id = ? AND o.created_at >= ?
            GROUP BY oi.menu_item_id, oi.note, oi.unit_price, oi.name
            ORDER BY MIN(oi.id)
            ''',
            [id, openedAt],
          ).map((r) => Map<String, Object?>.from(r)).toList();
    final subtotal = items.fold<int>(0, (sum, it) => sum + (it['lineTotal'] as int));
    final serviceFee = (subtotal * 0.1).round();
    return {
      'table': table,
      'items': items,
      'subtotal': subtotal,
      'serviceFee': serviceFee,
      'total': subtotal + serviceFee,
    };
  }

  // ---- Menu ---------------------------------------------------------------

  List<Map<String, Object?>> listMenu() {
    return _db
        .select(
          'SELECT id, name, price, category, popular, description, tags, stripe_a AS stripeA, stripe_b AS stripeB '
          'FROM menu_items ORDER BY sort_order, id',
        )
        .map((r) {
          final m = Map<String, Object?>.from(r);
          m['popular'] = m['popular'] == 1;
          m['tags'] = (m['tags'] as String).isEmpty ? <String>[] : (m['tags'] as String).split('|');
          return m;
        })
        .toList();
  }

  // ---- Orders ---------------------------------------------------------------

  Map<String, Object?> createOrder(int tableId, List<Map<String, Object?>> items) {
    if (items.isEmpty) throw ApiError('Sipariş en az bir ürün içermeli.');
    final table = _getTableRow(tableId);
    if (table['status'] != 'occupied' && table['status'] != 'billPending') {
      throw ApiError('Sipariş göndermeden önce masa açılmalı.', statusCode: 409);
    }

    final resolvedItems = <Map<String, Object?>>[];
    for (final raw in items) {
      final menuItemId = raw['menuItemId'] as String?;
      final qty = raw['qty'] as int? ?? 1;
      final note = (raw['note'] as String?)?.trim() ?? '';
      if (menuItemId == null || menuItemId.isEmpty) throw ApiError('Geçersiz ürün.');
      if (qty <= 0) throw ApiError('Adet 0’dan büyük olmalı.');
      final menuRows = _db.select('SELECT name, price FROM menu_items WHERE id = ?', [menuItemId]);
      if (menuRows.isEmpty) throw ApiError('Menüde olmayan bir ürün: $menuItemId', statusCode: 404);
      final menuRow = menuRows.first;
      resolvedItems.add({
        'menuItemId': menuItemId,
        'name': menuRow['name'],
        'qty': qty,
        'note': note,
        'unitPrice': menuRow['price'],
      });
    }

    final nextNumber =
        (_db.select('SELECT COALESCE(MAX(order_number), 4821) AS m FROM orders').first['m'] as int) + 1;
    final createdAt = DateTime.now().toIso8601String();
    _db.execute(
      "INSERT INTO orders (order_number, table_id, created_at, status) VALUES (?, ?, ?, 'preparing')",
      [nextNumber, tableId, createdAt],
    );
    final orderId = _db.lastInsertRowId;
    for (final it in resolvedItems) {
      _db.execute(
        'INSERT INTO order_items (order_id, menu_item_id, name, qty, note, unit_price) VALUES (?, ?, ?, ?, ?, ?)',
        [orderId, it['menuItemId'], it['name'], it['qty'], it['note'], it['unitPrice']],
      );
    }

    final subtotal = resolvedItems.fold<int>(0, (sum, it) => sum + (it['qty'] as int) * (it['unitPrice'] as int));
    final serviceFee = (subtotal * 0.1).round();
    final itemCount = resolvedItems.fold<int>(0, (sum, it) => sum + (it['qty'] as int));

    return {
      'orderNumber': nextNumber,
      'tableId': tableId,
      'table': _getTableRow(tableId),
      'items': resolvedItems,
      'itemCount': itemCount,
      'subtotal': subtotal,
      'serviceFee': serviceFee,
      'total': subtotal + serviceFee,
      'createdAt': createdAt,
    };
  }

  // ---- Mutfak -------------------------------------------------------------

  /// Şu an mutfakta hazırlanan siparişleri masa bazında gruplayarak döndürür
  /// (en eski sipariş bekleyen masa önce).
  List<Map<String, Object?>> kitchenQueue() {
    final orders = _db.select('''
      SELECT o.id AS id, o.order_number AS orderNumber, o.table_id AS tableId, o.created_at AS createdAt
      FROM orders o
      JOIN tables t ON t.id = o.table_id
      WHERE o.status = 'preparing'
        AND t.status IN ('occupied', 'billPending')
        AND t.opened_at IS NOT NULL AND o.created_at >= t.opened_at
      ORDER BY o.created_at, o.id
    ''');
    final byTable = <int, List<Map<String, Object?>>>{};
    for (final o in orders) {
      final items = _db.select(
        'SELECT name, qty, note FROM order_items WHERE order_id = ? ORDER BY id',
        [o['id']],
      ).map((r) => Map<String, Object?>.from(r)).toList();
      byTable.putIfAbsent(o['tableId'] as int, () => []).add({
        'id': o['id'],
        'orderNumber': o['orderNumber'],
        'createdAt': o['createdAt'],
        'items': items,
      });
    }
    return [
      for (final entry in byTable.entries) {'table': _getTableRow(entry.key), 'orders': entry.value},
    ];
  }

  /// Bir siparişi "hazır / servis edildi" olarak işaretler; mutfak listesinden düşer.
  Map<String, Object?> markOrderServed(int orderId) {
    final rows = _db.select('SELECT table_id FROM orders WHERE id = ?', [orderId]);
    if (rows.isEmpty) throw ApiError('Sipariş bulunamadı.', statusCode: 404);
    _db.execute("UPDATE orders SET status = 'served' WHERE id = ?", [orderId]);
    return {'orderId': orderId, 'table': _getTableRow(rows.first['table_id'] as int)};
  }

  /// Tam durumu (alanlar + masalar + menü + kategoriler) tek seferde
  /// döndürür; uygulama açılışında ve pull-to-refresh'te kullanılır.
  Map<String, Object?> bootstrap() {
    return {
      'areas': listAreas(),
      'tables': listTables(),
      'menu': listMenu(),
      'categories': menuCategories,
    };
  }
}
