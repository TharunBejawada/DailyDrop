// lib/features/orders/customer_orders_realtime.dart
//
// Listens only for updates to THIS user's own orders (filtered server-side,
// not just client-side) — so the moment admin marks an order "Out for
// delivery" or "Delivered", the customer's screen updates without them
// having to pull-to-refresh.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import 'customer_orders_provider.dart';

final customerOrdersRealtimeProvider = StreamProvider<void>((ref) {
  final controller = StreamController<void>();
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) {
    controller.close();
    return controller.stream;
  }

  final channel = supabase
      .channel('customer-orders-realtime-$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          ref.invalidate(customerOrdersProvider);
          controller.add(null);
        },
      )
      .subscribe();

  ref.onDispose(() {
    controller.close();
    supabase.removeChannel(channel);
  });

  return controller.stream;
});