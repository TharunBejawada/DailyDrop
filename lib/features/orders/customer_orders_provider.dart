// lib/features/orders/customer_orders_provider.dart
//
// RLS ("orders: owner read") already restricts this to the logged-in
// user's own orders — no need to filter by user_id client-side.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';

class CustomerOrderItem {
  final String productName;
  final String unit;
  final int quantity;
  final double priceAtOrder;
  CustomerOrderItem({
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.priceAtOrder,
  });
}

class CustomerOrder {
  final String id;
  final String orderType;
  final String status;
  final String deliverySlot;
  final double totalAmount;
  final DateTime createdAt;
  final String addressLandmark;
  final List<CustomerOrderItem> items;

  CustomerOrder({
    required this.id,
    required this.orderType,
    required this.status,
    required this.deliverySlot,
    required this.totalAmount,
    required this.createdAt,
    required this.addressLandmark,
    required this.items,
  });

  factory CustomerOrder.fromMap(Map<String, dynamic> map) {
    final address = map['addresses'] as Map<String, dynamic>?;
    final itemRows = (map['order_items'] as List?) ?? [];

    return CustomerOrder(
      id: map['id'] as String,
      orderType: map['order_type'] as String,
      status: map['status'] as String,
      deliverySlot: (map['delivery_slot'] as String?) ?? '',
      totalAmount: (map['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      addressLandmark: address?['landmark'] as String? ?? '',
      items: itemRows.map((row) {
        final product = row['products'] as Map<String, dynamic>?;
        return CustomerOrderItem(
          productName: product?['name'] as String? ?? 'Unknown item',
          unit: product?['unit'] as String? ?? '',
          quantity: row['quantity'] as int,
          priceAtOrder: (row['price_at_order'] as num).toDouble(),
        );
      }).toList(),
    );
  }
}

final customerOrdersProvider = FutureProvider<List<CustomerOrder>>((ref) async {
  final rows = await supabase
      .from('orders')
      .select('*, addresses(landmark), order_items(quantity, price_at_order, products(name, unit))')
      .order('created_at', ascending: false);

  return (rows as List).map((m) => CustomerOrder.fromMap(m as Map<String, dynamic>)).toList();
});