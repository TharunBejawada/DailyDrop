// lib/features/cart/cart_provider.dart
//
// Simple in-memory cart. Each entry stores the product itself (not just an
// id) so the cart screen and total-price calculation don't need to re-fetch
// anything. This resets if the app restarts — persisting it (or turning it
// into a real "orders" write) is part of the checkout step, not this one.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';

class CartItem {
  final Product product;
  final int quantity;
  CartItem({required this.product, required this.quantity});

  double get subtotal => product.price * quantity;
}

class CartNotifier extends StateNotifier<Map<String, CartItem>> {
  CartNotifier() : super({});

  void add(Product product) {
    final existing = state[product.id];
    final qty = (existing?.quantity ?? 0) + 1;
    state = {...state, product.id: CartItem(product: product, quantity: qty)};
  }

  void remove(Product product) {
    final existing = state[product.id];
    if (existing == null) return;
    if (existing.quantity <= 1) {
      final next = {...state}..remove(product.id);
      state = next;
    } else {
      state = {
        ...state,
        product.id: CartItem(product: product, quantity: existing.quantity - 1),
      };
    }
  }

  int quantityOf(String productId) => state[productId]?.quantity ?? 0;

  int get totalItems => state.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => state.values.fold(0.0, (sum, item) => sum + item.subtotal);

  void clear() => state = {};
}

final cartProvider = StateNotifierProvider<CartNotifier, Map<String, CartItem>>(
  (ref) => CartNotifier(),
);