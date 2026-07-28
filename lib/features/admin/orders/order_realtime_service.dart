// lib/features/admin/orders/order_realtime_service.dart
//
// Subscribes to Postgres changes on the `orders` table and emits an event
// for every new INSERT — this is what makes new orders show up instantly
// for you as admin, instead of needing to pull-to-refresh.
//
// Realtime respects the same RLS policies as normal queries, so this only
// ever fires for rows an admin account is allowed to see — which, per the
// schema, is all orders.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';
import 'admin_orders_provider.dart';

class NewOrderAlert {
  final String orderType;
  final double totalAmount;
  NewOrderAlert({required this.orderType, required this.totalAmount});
}

final newOrderAlertProvider = StreamProvider<NewOrderAlert>((ref) {
  final controller = StreamController<NewOrderAlert>();

  final channel = supabase
      .channel('admin-orders-realtime')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'orders',
        callback: (payload) {
          final row = payload.newRecord;
          controller.add(NewOrderAlert(
            orderType: row['order_type'] as String,
            totalAmount: (row['total_amount'] as num).toDouble(),
          ));
          // The insert payload doesn't include the joined address/items —
          // refresh the full list so the queue shows complete details.
          ref.invalidate(adminOrdersProvider);
        },
      )
      .subscribe();

  ref.onDispose(() {
    controller.close();
    supabase.removeChannel(channel);
  });

  return controller.stream;
});