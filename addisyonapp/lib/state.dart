import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'models.dart';

/// Uygulamanın tüm durumunu (alanlar, masalar, menü, sepet) tutan tekil
/// kaynak. Gerçek veri backend'den (`ApiClient`) gelir; bu sınıf sadece
/// önbelleğe alır, ekranlara sunar ve mutasyonları API'ye iletir. Ekranlar
/// bunu `provider` üzerinden dinler.
class RestaurantState extends ChangeNotifier {
  RestaurantState({ApiClient? apiClient}) : _api = apiClient ?? ApiClient() {
    init();
  }

  final ApiClient _api;

  List<RestaurantArea> areas = [];
  List<RestaurantTable> tables = [];
  List<MenuItem> menu = [];
  List<String> categories = [];

  bool isLoading = true;
  String? error;

  RestaurantTable? _selectedTable;
  RestaurantTable? get selectedTable => _selectedTable;

  final List<CartItem> _cart = [];
  List<CartItem> get cart => List.unmodifiable(_cart);

  SubmittedOrder? lastOrder;

  List<KitchenTicket> kitchen = [];

  // ---- Yükleme ---------------------------------------------------------

  /// Backend'den tüm başlangıç verisini (alanlar, masalar, menü) çeker.
  /// İlk açılışta constructor tarafından, sonrasında da "yeniden dene" /
  /// pull-to-refresh ile çağrılır.
  Future<void> init() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final boot = await _api.fetchBootstrap();
      areas = boot.areas;
      tables = boot.tables;
      menu = boot.menu;
      categories = boot.categories;
      if (_selectedTable != null) {
        final match = tables.where((t) => t.id == _selectedTable!.id);
        _selectedTable = match.isEmpty ? null : match.first;
      }
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Beklenmeyen bir hata oluştu: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => init();

  void _applyTableUpdate(RestaurantTable updated) {
    final idx = tables.indexWhere((t) => t.id == updated.id);
    if (idx != -1) {
      tables[idx] = updated;
    } else {
      tables.add(updated);
    }
    if (_selectedTable?.id == updated.id) {
      _selectedTable = updated;
    }
  }

  // ---- Masa seçimi -------------------------------------------------

  /// Masaya dokunulduğunda çağrılır. Masa müsaitse backend'de açar (durumu
  /// "dolu" yapar); zaten doluysa sadece seçili masa olarak işaretler.
  /// Hata durumunda [ApiException] fırlatır — çağıran taraf yakalayıp
  /// kullanıcıya göstermelidir.
  Future<void> selectTable(RestaurantTable table) async {
    if (table.status == TableStatus.available || table.status == TableStatus.empty) {
      // Açma başarısız olursa (örn. sunucu kapalı) masa seçili kalmamalı;
      // aksi halde menü, açılmamış bir masayı "AÇIK" gösterir.
      final updated = await _api.openTable(table.id, guests: table.guests == 0 ? 2 : table.guests);
      _applyTableUpdate(updated);
      _selectedTable = updated;
    } else {
      _selectedTable = table;
    }
    notifyListeners();
  }

  int get openTableCount =>
      tables.where((t) => t.status != TableStatus.available && t.status != TableStatus.empty).length;

  int get availableCount => tables.where((t) => t.status == TableStatus.available).length;
  int get occupiedCount => tables.where((t) => t.status == TableStatus.occupied).length;
  int get billPendingCount => tables.where((t) => t.status == TableStatus.billPending).length;

  List<RestaurantTable> get tablesWithOpenBill =>
      tables.where((t) => t.status == TableStatus.occupied || t.status == TableStatus.billPending).toList();

  // ---- Masa yönetimi (ekle / düzenle / sil) ------------------------------

  Future<RestaurantTable> createTable({required String name, required int areaId}) async {
    final table = await _api.createTable(name: name, areaId: areaId);
    tables.add(table);
    notifyListeners();
    return table;
  }

  Future<void> updateTable(RestaurantTable table, {String? name, int? areaId}) async {
    final updated = await _api.updateTable(table.id, name: name, areaId: areaId);
    _applyTableUpdate(updated);
    notifyListeners();
  }

  Future<void> deleteTable(RestaurantTable table) async {
    await _api.deleteTable(table.id);
    tables.removeWhere((t) => t.id == table.id);
    if (_selectedTable?.id == table.id) {
      _selectedTable = null;
    }
    notifyListeners();
  }

  Future<RestaurantArea> createArea(String name) async {
    final area = await _api.createArea(name);
    areas.add(area);
    notifyListeners();
    return area;
  }

  /// Bir alandaki masalar arasında kullanılmayan en küçük "Masa N" adını
  /// önerir; masa ekleme diyaloğunda varsayılan değer olarak kullanılır.
  String suggestTableName() {
    final used = tables
        .map((t) => RegExp(r'^Masa (\d+)$').firstMatch(t.name)?.group(1))
        .whereType<String>()
        .map(int.parse)
        .toSet();
    var n = 1;
    while (used.contains(n)) {
      n++;
    }
    return 'Masa $n';
  }

  // ---- Sepet ---------------------------------------------------------

  int get cartItemCount => _cart.fold(0, (sum, ci) => sum + ci.qty);
  int get cartSubtotal => _cart.fold(0, (sum, ci) => sum + ci.lineTotal);
  int get cartServiceFee => (cartSubtotal * 0.1).round();
  int get cartTotal => cartSubtotal + cartServiceFee;

  void addToCart(MenuItem item, {int qty = 1, String note = ''}) {
    note = note.trim();
    final existingIndex = _cart.indexWhere((ci) => ci.item.id == item.id && ci.note == note);
    if (existingIndex != -1) {
      _cart[existingIndex].qty += qty;
    } else {
      _cart.add(CartItem(item: item, qty: qty, note: note));
    }
    notifyListeners();
  }

  void incrementCartItem(CartItem cartItem) {
    cartItem.qty++;
    notifyListeners();
  }

  void decrementCartItem(CartItem cartItem) {
    cartItem.qty--;
    if (cartItem.qty <= 0) {
      _cart.remove(cartItem);
    }
    notifyListeners();
  }

  void removeCartItem(CartItem cartItem) {
    _cart.remove(cartItem);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  // ---- Sipariş gönderme -----------------------------------------------

  Future<SubmittedOrder> submitOrder() async {
    final table = _selectedTable;
    if (table == null || _cart.isEmpty) {
      throw StateError('Sipariş göndermek için masa ve sepet dolu olmalı.');
    }
    final order = await _api.submitOrder(tableId: table.id, items: _cart);
    _applyTableUpdate(order.table);
    lastOrder = order;
    _cart.clear();
    notifyListeners();
    return order;
  }

  // ---- Mutfak -------------------------------------------------------------

  /// Mutfakta hazırlanan siparişleri yeniler. Hata olursa [ApiException]
  /// fırlatır; çağıran ekran gösterir.
  Future<void> loadKitchen() async {
    kitchen = await _api.fetchKitchen();
    // Mutfak listesindeki masa bilgileri de güncel; salon kartları
    // ("MUTFAKTA" etiketi) aynı veriyle tazelensin.
    for (final ticket in kitchen) {
      _applyTableUpdate(ticket.table);
    }
    notifyListeners();
  }

  Future<void> markOrderServed(KitchenOrder order) async {
    final table = await _api.markOrderServed(order.id);
    _applyTableUpdate(table);
    await loadKitchen();
  }

  // ---- Hesap / ödeme ---------------------------------------------------

  Future<BillDetail> fetchBill(RestaurantTable table) => _api.fetchBill(table.id);

  Future<void> requestBill(RestaurantTable table) async {
    final updated = await _api.requestBill(table.id);
    _applyTableUpdate(updated);
    notifyListeners();
  }

  Future<void> settleBill(RestaurantTable table) async {
    final updated = await _api.settleBill(table.id);
    _applyTableUpdate(updated);
    if (identical(_selectedTable, table) || _selectedTable?.id == table.id) {
      _selectedTable = null;
    }
    notifyListeners();
  }
}
