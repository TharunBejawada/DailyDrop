// lib/features/orders/customer_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/status_badge.dart';
import '../admin/orders/admin_order_service.dart' show orderStatusFlow;
import '../auth/login_screen.dart';
import '../home/home_tab_provider.dart';
import 'customer_orders_provider.dart';
import 'customer_orders_realtime.dart';

// orderStatusFlow (admin_order_service.dart) is the single source of truth
// for stage order — only the labels/icons below are presentation-only.
const _stepLabels = ['Placed', 'Confirmed', 'On the way', 'Delivered'];
const _stepIcons = [
  Icons.receipt_long_outlined,
  Icons.inventory_2_outlined,
  Icons.delivery_dining_outlined,
  Icons.home_outlined,
];

/// Orders tab inside CustomerHomeShell — no own Scaffold/AppBar, the shell
/// provides those. Requires a session (RLS-scoped query), so guests see a
/// sign-in prompt instead of hitting customerOrdersProvider at all.
class CustomerOrdersScreen extends ConsumerWidget {
  const CustomerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (supabase.auth.currentSession == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: AppIconSize.hero,
                  color: AppSemantic.of(context).mutedText),
              const SizedBox(height: AppSpacing.lg),
              Text('No orders to show',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Sign in to view and track your orders.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppSemantic.of(context).mutedText),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      );
    }

    // Just subscribing is enough to trigger invalidation of the list above
    // when a status changes — the screen doesn't need this stream's data directly.
    ref.watch(customerOrdersRealtimeProvider);

    final ordersAsync = ref.watch(customerOrdersProvider);
    final gutter = AppSpacing.gutterFor(MediaQuery.sizeOf(context).width);

    return ordersAsync.when(
      loading: () => const ListSkeleton(itemHeight: 180),
      error: (e, _) => ErrorState(
        title: 'Could not load your orders',
        error: e,
        onRetry: () => ref.invalidate(customerOrdersProvider),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No orders yet',
            message: 'Once you place an order, you can track it here.',
            action: FilledButton.icon(
              onPressed: () =>
                  ref.read(homeTabIndexProvider.notifier).state = 0,
              icon: const Icon(Icons.storefront_outlined, size: AppIconSize.md),
              label: const Text('Start shopping'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(customerOrdersProvider.future),
          child: ListView.separated(
            padding:
                EdgeInsets.fromLTRB(gutter, gutter, gutter, AppSpacing.xxl),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _OrderCard(
              key: ValueKey(orders[index].id),
              order: orders[index],
            ),
          ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final CustomerOrder order;
  const _OrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final isCancelled = order.status == 'cancelled';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: OrderTypeChip(orderType: order.orderType)),
                Text(
                  currency.format(order.totalAmount),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _MetaRow(
              icon: Icons.location_on_outlined,
              text: order.addressLandmark,
            ),
            const SizedBox(height: AppSpacing.xs),
            _MetaRow(
              icon: Icons.schedule_outlined,
              text:
                  DateFormat('d MMM, h:mm a').format(order.createdAt.toLocal()),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (isCancelled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: semantic.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border:
                      Border.all(color: semantic.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined,
                        size: AppIconSize.md, color: semantic.danger),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'This order was cancelled',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: semantic.danger),
                    ),
                  ],
                ),
              )
            else
              _StatusTracker(currentStatus: order.status),
            const Divider(),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${item.quantity} × ${item.unit}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: semantic.mutedText),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    return Row(
      children: [
        Icon(icon, size: AppIconSize.sm, color: semantic.mutedText),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                theme.textTheme.bodySmall?.copyWith(color: semantic.mutedText),
          ),
        ),
      ],
    );
  }
}

/// Horizontal progress tracker. Each completed step gets a filled dot with a
/// check icon plus a bolder label, so progress is legible without relying on
/// the green tint alone.
class _StatusTracker extends StatelessWidget {
  final String currentStatus;
  const _StatusTracker({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final currentIndex = orderStatusFlow.indexOf(currentStatus);

    return Semantics(
      label: 'Order status: '
          '${currentIndex >= 0 ? _stepLabels[currentIndex] : currentStatus}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(orderStatusFlow.length * 2 - 1, (i) {
          // Odd indices are the connector lines between dots.
          if (i.isOdd) {
            final done = (i ~/ 2) < currentIndex;
            return Expanded(
              child: Padding(
                // Align with the vertical centre of the 28px dots above.
                padding: const EdgeInsets.only(top: 13),
                child: AnimatedContainer(
                  duration: AppMotion.normal,
                  height: 2,
                  color: done ? semantic.success : semantic.trackInactive,
                ),
              ),
            );
          }

          final stepIndex = i ~/ 2;
          final isDone = stepIndex <= currentIndex;
          final isCurrent = stepIndex == currentIndex;

          final dot = AnimatedContainer(
            duration: AppMotion.normal,
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDone ? semantic.success : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDone ? semantic.success : semantic.trackInactive,
                width: 2,
              ),
            ),
            child: Icon(
              isDone ? Icons.check : _stepIcons[stepIndex],
              size: AppIconSize.sm,
              color: isDone ? theme.colorScheme.onPrimary : semantic.mutedText,
            ),
          );

          return SizedBox(
            width: 60,
            child: Column(
              children: [
                // Re-keying on currentIndex replays the pulse each time a
                // step newly becomes current (e.g. a Realtime status update),
                // not just on first paint.
                isCurrent
                    ? dot
                        .animate(key: ValueKey('pulse-$currentIndex'))
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.25, 1.25),
                          duration: AppMotion.fast,
                          curve: Curves.easeOut,
                        )
                        .then()
                        .scale(
                          begin: const Offset(1.25, 1.25),
                          end: const Offset(1, 1),
                          duration: AppMotion.fast,
                          curve: Curves.easeIn,
                        )
                    : dot,
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _stepLabels[stepIndex],
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDone
                        ? theme.colorScheme.onSurface
                        : semantic.mutedText,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
