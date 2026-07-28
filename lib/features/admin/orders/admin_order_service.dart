// lib/features/admin/orders/admin_order_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase_client.dart';
import 'admin_orders_provider.dart';

const orderStatusFlow = ['placed', 'confirmed', 'out_for_delivery', 'delivered'];

String? nextStatus(String current) {
  final index = orderStatusFlow.indexOf(current);
  if (index == -1 || index == orderStatusFlow.length - 1) return null;
  return orderStatusFlow[index + 1];
}

final adminOrderServiceProvider = Provider((ref) => AdminOrderService(ref));

class AdminOrderService {
  final Ref ref;
  AdminOrderService(this.ref);

  Future<void> advanceStatus(String orderId, String currentStatus) async {
    final next = nextStatus(currentStatus);
    if (next == null) return;
    await supabase.from('orders').update({'status': next}).eq('id', orderId);
    ref.invalidate(adminOrdersProvider);
  }

  Future<void> cancelOrder(String orderId) async {
    await supabase.from('orders').update({'status': 'cancelled'}).eq('id', orderId);
    ref.invalidate(adminOrdersProvider);
  }
}