// lib/features/admin/orders/admin_orders_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase_client.dart';

class AdminOrderItem {
  final String productName;
  final String unit;
  final int quantity;
  final double priceAtOrder;
  AdminOrderItem({
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.priceAtOrder,
  });
}

class AdminOrder {
  final String id;
  final String orderType;
  final String status;
  final String deliverySlot;
  final String paymentMethod;
  final double totalAmount;
  final DateTime createdAt;
  final String addressLandmark;
  final String addressPhone;
  final List<AdminOrderItem> items;

  AdminOrder({
    required this.id,
    required this.orderType,
    required this.status,
    required this.deliverySlot,
    required this.paymentMethod,
    required this.totalAmount,
    required this.createdAt,
    required this.addressLandmark,
    required this.addressPhone,
    required this.items,
  });

  factory AdminOrder.fromMap(Map<String, dynamic> map) {
    final address = map['addresses'] as Map<String, dynamic>?;
    final itemRows = (map['order_items'] as List?) ?? [];

    return AdminOrder(
      id: map['id'] as String,
      orderType: map['order_type'] as String,
      status: map['status'] as String,
      deliverySlot: (map['delivery_slot'] as String?) ?? '',
      paymentMethod: map['payment_method'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      addressLandmark: address?['landmark'] as String? ?? '',
      addressPhone: address?['phone'] as String? ?? '',
      items: itemRows.map((row) {
        final product = row['products'] as Map<String, dynamic>?;
        return AdminOrderItem(
          productName: product?['name'] as String? ?? 'Unknown item',
          unit: product?['unit'] as String? ?? '',
          quantity: row['quantity'] as int,
          priceAtOrder: (row['price_at_order'] as num).toDouble(),
        );
      }).toList(),
    );
  }
}

// Admin's RLS policy (is_admin()) lets this see every user's orders, not
// just their own — that's the point of the admin queue.
final adminOrdersProvider = FutureProvider<List<AdminOrder>>((ref) async {
  final rows = await supabase
      .from('orders')
      .select('*, addresses(landmark, phone), order_items(quantity, price_at_order, products(name, unit))')
      .order('created_at', ascending: false);

  return (rows as List).map((m) => AdminOrder.fromMap(m as Map<String, dynamic>)).toList();
});