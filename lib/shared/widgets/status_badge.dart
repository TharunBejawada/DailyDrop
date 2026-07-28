// lib/shared/widgets/status_badge.dart
//
// Order-status pill. Each status carries BOTH a colour and its own icon, so
// status is never communicated by colour alone (colour-blind users, and
// anyone glancing at a phone in sunlight).

import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

const orderStatusLabels = {
  'placed': 'Placed',
  'confirmed': 'Confirmed',
  'out_for_delivery': 'Out for delivery',
  'delivered': 'Delivered',
  'cancelled': 'Cancelled',
};

const _statusIcons = {
  'placed': Icons.receipt_long_outlined,
  'confirmed': Icons.check_circle_outline,
  'out_for_delivery': Icons.delivery_dining_outlined,
  'delivered': Icons.task_alt,
  'cancelled': Icons.cancel_outlined,
};

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);

    final color = switch (status) {
      'delivered' => semantic.success,
      'out_for_delivery' => semantic.info,
      'confirmed' => semantic.warning,
      'cancelled' => semantic.danger,
      _ => semantic.mutedText,
    };

    final label = orderStatusLabels[status] ?? status;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcons[status] ?? Icons.circle_outlined,
              size: AppIconSize.sm, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Small pill marking which fulfilment track an order/product belongs to.
/// 'mixed' covers a cart that had both groceries and fruit/veg — since both
/// now fulfill on the same schedule, that's a single merged order rather
/// than two.
class OrderTypeChip extends StatelessWidget {
  final String orderType; // 'grocery' | 'fruit_veg' | 'mixed'
  const OrderTypeChip({super.key, required this.orderType});

  static String labelFor(String orderType) => switch (orderType) {
        'grocery' => 'Grocery',
        'fruit_veg' => 'Fruits & Vegetables',
        _ => 'Grocery + Fruits & Veg',
      };

  static IconData _iconFor(String orderType) => switch (orderType) {
        'grocery' => Icons.shopping_basket_outlined,
        'fruit_veg' => Icons.eco_outlined,
        _ => Icons.shopping_bag_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final color = switch (orderType) {
      'grocery' => semantic.grocery,
      'fruit_veg' => semantic.fruitVeg,
      _ => theme.colorScheme.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(orderType), size: AppIconSize.sm, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            labelFor(orderType),
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
