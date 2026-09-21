import 'package:flutter/material.dart';

/// Bir masanın servis durumu.
enum TableStatus { available, occupied, billPending, empty }

TableStatus tableStatusFromApi(String value) {
  return TableStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => TableStatus.available,
  );
}

/// Salon/Teras/Bar gibi bir servis alanı. Backend'de masalar bir alana bağlı
/// tutulur; alanlar da yönetilebilir (yeni alan eklenebilir).
class RestaurantArea {
  RestaurantArea({required this.id, required this.name});

  final int id;
  final String name;

  factory RestaurantArea.fromJson(Map<String, dynamic> json) {
    return RestaurantArea(id: json['id'] as int, name: json['name'] as String);
  }
}

class RestaurantTable {
  RestaurantTable({
    required this.id,
    required this.name,
    required this.areaId,
    required this.area,
    required this.status,
    this.statusLabel,
    this.guests = 0,
    this.openedAt,
    this.billTotal = 0,
    this.kitchenCount = 0,
  });

  final int id;
  String name;
  int areaId;
  String area;
  TableStatus status;
  int guests;

  /// Durum etiketi (örn. "ANA YEMEK"); boşsa varsayılan etiket kullanılır.
  String? statusLabel;

  /// Masanın açıldığı zaman; süre hesaplamak için kullanılır.
  DateTime? openedAt;

  /// Bu servis oturumunda (masa açıldığından beri) mutfağa gönderilmiş
  /// siparişlerin ara toplamı. Backend tarafından hesaplanır.
  int billTotal;

  /// Mutfakta hâlâ hazırlanan sipariş sayısı (masa → mutfak → hesap → ödeme
  /// döngüsünün "mutfak" adımı). Backend tarafından hesaplanır.
  int kitchenCount;

  factory RestaurantTable.fromJson(Map<String, dynamic> json) {
    return RestaurantTable(
      id: json['id'] as int,
      name: json['name'] as String,
      areaId: json['areaId'] as int,
      area: json['areaName'] as String,
      status: tableStatusFromApi(json['status'] as String),
      statusLabel: json['statusLabel'] as String?,
      guests: json['guests'] as int,
      openedAt: json['openedAt'] == null ? null : DateTime.parse(json['openedAt'] as String),
      billTotal: json['billTotal'] as int,
      kitchenCount: json['kitchenCount'] as int? ?? 0,
    );
  }

  String get defaultStatusLabel {
    switch (status) {
      case TableStatus.available:
        return 'MÜSAİT';
      case TableStatus.occupied:
        return kitchenCount > 0 ? 'MUTFAKTA' : 'DOLU';
      case TableStatus.billPending:
        return 'HESAP';
      case TableStatus.empty:
        return 'BOŞ';
    }
  }

  String get label => statusLabel ?? defaultStatusLabel;

  String get timeLabel {
    if (openedAt == null) return '—';
    // Cihaz saati sunucudan az da olsa geride kalabilir (emülatörlerde ve
    // gerçek cihazlarda saat kayması yaygındır); negatif süre göstermek
    // yerine 0'a kenetliyoruz.
    final minutes = DateTime.now().difference(openedAt!).inMinutes;
    return '${minutes < 0 ? 0 : minutes} dk';
  }

  int get billServiceFee => (billTotal * 0.1).round();
  int get billGrandTotal => billTotal + billServiceFee;
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.stripeA,
    required this.stripeB,
    this.popular = false,
    this.description = '',
    this.tags = const [],
  });

  final String id;
  final String name;
  final int price;
  final String category;
  final bool popular;
  final Color stripeA;
  final Color stripeB;
  final String description;
  final List<String> tags;

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      name: json['name'] as String,
      price: json['price'] as int,
      category: json['category'] as String,
      popular: json['popular'] as bool,
      stripeA: Color(json['stripeA'] as int),
      stripeB: Color(json['stripeB'] as int),
      description: json['description'] as String? ?? '',
      tags: (json['tags'] as List).cast<String>(),
    );
  }
}

class CartItem {
  CartItem({required this.item, this.qty = 1, this.note = ''});

  final MenuItem item;
  int qty;
  String note;

  int get lineTotal => item.price * qty;

  String get noteLabel => note.trim().isEmpty ? 'Not yok' : note.trim();
}

/// Hesap detayında görünen, mutfağa gönderilmiş tek bir kalem (aynı ürün +
/// aynı not birleştirilmiş halde).
class BillLineItem {
  BillLineItem({
    required this.menuItemId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.note,
  });

  final String menuItemId;
  final String name;
  final int qty;
  final int unitPrice;
  final String note;

  int get lineTotal => qty * unitPrice;

  factory BillLineItem.fromJson(Map<String, dynamic> json) {
    return BillLineItem(
      menuItemId: json['menuItemId'] as String,
      name: json['name'] as String,
      qty: json['qty'] as int,
      unitPrice: json['unitPrice'] as int,
      note: json['note'] as String? ?? '',
    );
  }
}

class BillDetail {
  BillDetail({
    required this.table,
    required this.items,
    required this.subtotal,
    required this.serviceFee,
    required this.total,
  });

  final RestaurantTable table;
  final List<BillLineItem> items;
  final int subtotal;
  final int serviceFee;
  final int total;

  factory BillDetail.fromJson(Map<String, dynamic> json) {
    return BillDetail(
      table: RestaurantTable.fromJson(json['table'] as Map<String, dynamic>),
      items: (json['items'] as List)
          .map((e) => BillLineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: json['subtotal'] as int,
      serviceFee: json['serviceFee'] as int,
      total: json['total'] as int,
    );
  }
}

class SubmittedOrder {
  SubmittedOrder({
    required this.orderNumber,
    required this.table,
    required this.itemCount,
    required this.subtotal,
    required this.serviceFee,
    required this.total,
  });

  final int orderNumber;
  final RestaurantTable table;
  final int itemCount;
  final int subtotal;
  final int serviceFee;
  final int total;
}

/// Mutfaktaki bir siparişin tek kalemi.
class KitchenLine {
  KitchenLine({required this.name, required this.qty, required this.note});

  final String name;
  final int qty;
  final String note;

  factory KitchenLine.fromJson(Map<String, dynamic> json) {
    return KitchenLine(
      name: json['name'] as String,
      qty: json['qty'] as int,
      note: json['note'] as String? ?? '',
    );
  }
}

/// Mutfakta hazırlanan tek bir sipariş.
class KitchenOrder {
  KitchenOrder({required this.id, required this.orderNumber, required this.createdAt, required this.items});

  final int id;
  final int orderNumber;
  final DateTime createdAt;
  final List<KitchenLine> items;

  int get itemCount => items.fold(0, (sum, it) => sum + it.qty);

  String get ageLabel {
    final minutes = DateTime.now().difference(createdAt).inMinutes;
    return '${minutes < 0 ? 0 : minutes} dk';
  }

  factory KitchenOrder.fromJson(Map<String, dynamic> json) {
    return KitchenOrder(
      id: json['id'] as int,
      orderNumber: json['orderNumber'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: (json['items'] as List).map((e) => KitchenLine.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// Mutfakta siparişi hazırlanan bir masa ve o masanın bekleyen siparişleri.
class KitchenTicket {
  KitchenTicket({required this.table, required this.orders});

  final RestaurantTable table;
  final List<KitchenOrder> orders;

  factory KitchenTicket.fromJson(Map<String, dynamic> json) {
    return KitchenTicket(
      table: RestaurantTable.fromJson(json['table'] as Map<String, dynamic>),
      orders: (json['orders'] as List).map((e) => KitchenOrder.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
