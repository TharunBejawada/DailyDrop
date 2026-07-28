// lib/features/checkout/order_service.dart
//
// Grocery and fruit/veg now fulfill on the same schedule, so checkout
// creates a single order per checkout regardless of what's in the cart.
// orders.order_type is 'grocery', 'fruit_veg', or 'mixed' when the cart has
// both — the Supabase schema's check constraint on that column must allow
// 'mixed' (see PLAN.md's Phase 1 notes).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';
import '../cart/cart_provider.dart';
import 'delivery_slot.dart';

final orderServiceProvider = Provider((ref) => OrderService());

class OrderService {
  /// Returns the new order's ID, as a single-element list (kept as a list
  /// since checkout screen and post-payment marking iterate over it).
  Future<List<String>> placeOrder({
    required Map<String, CartItem> cart,
    required String addressId,
    required String paymentMethod, // 'upi' or 'cod'
  }) async {
    final userId = supabase.auth.currentUser!.id;
    final items = cart.values.toList();
    if (items.isEmpty) return [];

    final hasGrocery = items.any((i) => i.product.productType == 'grocery');
    final hasFruitVeg = items.any((i) => i.product.productType == 'fruit_veg');
    final orderType = hasGrocery && hasFruitVeg
        ? 'mixed'
        : (hasFruitVeg ? 'fruit_veg' : 'grocery');

    final slot = deliverySlot();
    final id = await _createOrder(
      userId: userId,
      addressId: addressId,
      orderType: orderType,
      deliverySlot: slot.code,
      paymentMethod: paymentMethod,
      items: items,
    );

    return [id];
  }

  Future<String> _createOrder({
    required String userId,
    required String addressId,
    required String orderType,
    required String deliverySlot,
    required String paymentMethod,
    required List<CartItem> items,
  }) async {
    final total = items.fold(0.0, (sum, item) => sum + item.subtotal);

    final orderRow = await supabase
        .from('orders')
        .insert({
          'user_id': userId,
          'address_id': addressId,
          'order_type': orderType,
          'delivery_slot': deliverySlot,
          'payment_method': paymentMethod,
          'total_amount': total,
        })
        .select('id')
        .single();

    final orderId = orderRow['id'] as String;

    await supabase.from('order_items').insert([
      for (final item in items)
        {
          'order_id': orderId,
          'product_id': item.product.id,
          'quantity': item.quantity,
          'price_at_order': item.product.price,
        }
    ]);

    return orderId;
  }
}
