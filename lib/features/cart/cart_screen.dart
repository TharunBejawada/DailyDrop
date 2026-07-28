// lib/features/cart/cart_screen.dart
//
// The "Cart" tab inside CustomerHomeShell. Review-before-checkout step:
// browsing and adding items never requires login (see catalog_screen.dart),
// but proceeding from here does — requireLogin() gates the checkout push.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/auth_guard.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_states.dart';
import '../checkout/checkout_screen.dart';
import '../home/home_tab_provider.dart';
import 'cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final gutter = AppSpacing.gutterFor(MediaQuery.sizeOf(context).width);

    if (cart.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Your cart is empty',
        message: 'Add a few items from the store and they\'ll show up here.',
        action: FilledButton(
          onPressed: () => ref.read(homeTabIndexProvider.notifier).state = 0,
          child: const Text('Start shopping'),
        ),
      );
    }

    final items = cart.values.toList();

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: item.product.imageUrl == null
                              ? ColoredBox(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: Icon(Icons.shopping_basket_outlined,
                                      color: theme.colorScheme.onSurfaceVariant),
                                )
                              : CachedNetworkImage(
                                  imageUrl: item.product.imageUrl!,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              currency.format(item.product.price),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: semantic.mutedText),
                            ),
                          ],
                        ),
                      ),
                      _QtyStepper(
                        quantity: item.quantity,
                        onRemove: () => notifier.remove(item.product),
                        onAdd: () => notifier.add(item.product),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Total (${notifier.totalItems} items)',
                            style: theme.textTheme.bodyMedium),
                      ),
                      Text(
                        currency.format(notifier.totalPrice),
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                      onPressed: () async {
                        final canProceed = await requireLogin(context);
                        if (!canProceed || !context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: AppIconSize.md),
                      iconAlignment: IconAlignment.end,
                      label: const Text('Proceed to checkout'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onRemove;
  final VoidCallback onAdd;
  const _QtyStepper({required this.quantity, required this.onRemove, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: theme.colorScheme.primary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.remove, size: AppIconSize.sm),
            visualDensity: VisualDensity.compact,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          Text('$quantity', style: theme.textTheme.labelLarge),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: AppIconSize.sm),
            visualDensity: VisualDensity.compact,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ],
      ),
    );
  }
}
