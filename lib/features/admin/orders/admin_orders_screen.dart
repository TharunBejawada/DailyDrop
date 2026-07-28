// lib/features/admin/orders/admin_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/status_badge.dart';
import 'admin_order_service.dart';
import 'admin_orders_provider.dart';

class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(adminOrdersProvider);
    final gutter = AppSpacing.gutterFor(MediaQuery.sizeOf(context).width);

    return ordersAsync.when(
      loading: () => const ListSkeleton(itemHeight: 200),
      error: (e, _) => ErrorState(
        title: 'Could not load the order queue',
        error: e,
        onRetry: () => ref.invalidate(adminOrdersProvider),
      ),
      data: (orders) {
        // Active orders first, delivered/cancelled pushed to the bottom —
        // this is the queue you'll be checking constantly, keep it scannable.
        final sorted = [...orders]..sort((a, b) {
            int rank(String s) => s == 'delivered' || s == 'cancelled' ? 1 : 0;
            return rank(a.status).compareTo(rank(b.status));
          });

        if (sorted.isEmpty) {
          return const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No orders yet',
            message: 'New orders appear here the moment a customer places one.',
          );
        }

        final activeCount = sorted
            .where((o) => o.status != 'delivered' && o.status != 'cancelled')
            .length;

        return RefreshIndicator(
          onRefresh: () => ref.refresh(adminOrdersProvider.future),
          child: ListView.separated(
            padding:
                EdgeInsets.fromLTRB(gutter, gutter, gutter, AppSpacing.xxl),
            itemCount: sorted.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index == 0) return _QueueSummary(activeCount: activeCount);
              final order = sorted[index - 1];
              return _AdminOrderCard(key: ValueKey(order.id), order: order);
            },
          ),
        );
      },
    );
  }
}

class _QueueSummary extends StatelessWidget {
  final int activeCount;
  const _QueueSummary({required this.activeCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final isClear = activeCount == 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: (isClear ? semantic.success : semantic.warning)
            .withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: (isClear ? semantic.success : semantic.warning)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isClear
                ? Icons.check_circle_outline
                : Icons.pending_actions_outlined,
            size: AppIconSize.lg,
            color: isClear ? semantic.success : semantic.warning,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              isClear
                  ? 'All caught up — nothing waiting.'
                  : '$activeCount order${activeCount == 1 ? '' : 's'} need attention',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Drives the "advance status" button's morph. `success` is a brief hold
/// (see `_advance`) so the confirmation reads even though the button's own
/// row often disappears right after (canAct flips false, e.g. on delivered).
enum _AdvanceState { idle, advancing, success }

class _AdminOrderCard extends ConsumerStatefulWidget {
  final AdminOrder order;
  const _AdminOrderCard({super.key, required this.order});

  @override
  ConsumerState<_AdminOrderCard> createState() => _AdminOrderCardState();
}

class _AdminOrderCardState extends ConsumerState<_AdminOrderCard> {
  _AdvanceState _state = _AdvanceState.idle;

  Future<void> _advance() async {
    setState(() => _state = _AdvanceState.advancing);
    await ref
        .read(adminOrderServiceProvider)
        .advanceStatus(widget.order.id, widget.order.status);
    if (!mounted) return;
    setState(() => _state = _AdvanceState.success);
    await Future.delayed(AppMotion.normal);
    if (!mounted) return;
    setState(() => _state = _AdvanceState.idle);
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
          'The customer will see it as cancelled. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(adminOrderServiceProvider).cancelOrder(widget.order.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final next = nextStatus(order.status);
    final canAct = order.status != 'delivered' && order.status != 'cancelled';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: OrderTypeChip(orderType: order.orderType)),
                StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Address + phone are what you act on — keep them prominent.
            Text(
              order.addressLandmark,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.phone_outlined,
                    size: AppIconSize.sm, color: semantic.mutedText),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  order.addressPhone,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: semantic.mutedText),
                ),
                const Spacer(),
                Text(
                  DateFormat('d MMM, h:mm a').format(order.createdAt.toLocal()),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: semantic.mutedText),
                ),
              ],
            ),
            const Divider(),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${item.quantity}×',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${item.productName} (${item.unit})',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      currency.format(item.priceAtOrder * item.quantity),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: semantic.mutedText),
                    ),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    currency.format(order.totalAmount),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _PaymentTag(method: order.paymentMethod),
              ],
            ),
            if (canAct) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: (next == null || _state != _AdvanceState.idle)
                          ? null
                          : _advance,
                      child: AnimatedSwitcher(
                        duration: AppMotion.fast,
                        child: switch (_state) {
                          _AdvanceState.advancing => SizedBox(
                              key: const ValueKey('advancing'),
                              height: AppIconSize.md,
                              width: AppIconSize.md,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          _AdvanceState.success => Icon(
                              Icons.check_rounded,
                              key: const ValueKey('success'),
                              color: theme.colorScheme.onPrimary,
                              size: AppIconSize.md,
                            ),
                          _AdvanceState.idle => Row(
                              key: const ValueKey('idle'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(next == null
                                    ? 'Done'
                                    : orderStatusLabels[next] ?? next),
                                const SizedBox(width: AppSpacing.sm),
                                const Icon(Icons.arrow_forward,
                                    size: AppIconSize.md),
                              ],
                            ),
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(
                        color: theme.colorScheme.error.withValues(alpha: 0.5),
                      ),
                    ),
                    onPressed: () => _confirmCancel(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentTag extends StatelessWidget {
  final String method;
  const _PaymentTag({required this.method});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final isCod = method == 'cod';
    final color = isCod ? semantic.warning : semantic.success;

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
          Icon(
            isCod
                ? Icons.currency_rupee
                : Icons.account_balance_wallet_outlined,
            size: AppIconSize.sm,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            isCod ? 'Collect cash' : 'Paid online',
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
