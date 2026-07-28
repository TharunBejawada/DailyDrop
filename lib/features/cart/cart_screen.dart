// lib/features/cart/cart_screen.dart
//
// The "Cart" tab inside CustomerHomeShell. Review-before-checkout step:
// browsing and adding items never requires login (see catalog_screen.dart),
// but proceeding from here does — requireLogin() gates the checkout push.
//
// Row removal is animated via AnimatedList, keyed off the ordered product-id
// list kept in _order/_snapshot below. CartNotifier's state is a plain
// Map<String, CartItem> with no history of "what just left" — AnimatedList
// needs the outgoing row's content at the moment it's removed, so _snapshot
// caches each item's last-known data until its remove animation finishes.
// CartScreen itself is torn down and recreated on every tab switch (see
// CustomerHomeShell — body swaps by index, no IndexedStack), so this only
// ever animates changes made while the Cart tab is actually on-screen.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/auth_guard.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/animated_quantity_stepper.dart';
import '../../shared/widgets/app_states.dart';
import '../checkout/checkout_screen.dart';
import '../home/home_tab_provider.dart';
import 'cart_provider.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _listKey = GlobalKey<AnimatedListState>();
  late List<String> _order;
  late Map<String, CartItem> _snapshot;

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartProvider);
    _order = cart.keys.toList();
    _snapshot = Map.of(cart);
  }

  void _syncCart(Map<String, CartItem> next) {
    for (final id in next.keys) {
      if (!_snapshot.containsKey(id)) {
        final index = _order.length;
        _order.add(id);
        _snapshot[id] = next[id]!;
        _listKey.currentState?.insertItem(index, duration: AppMotion.normal);
      }
    }

    for (final id in List<String>.of(_order)) {
      if (!next.containsKey(id)) {
        final index = _order.indexOf(id);
        final removedItem = _snapshot[id]!;
        _order.removeAt(index);
        _snapshot.remove(id);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => _CartRow(item: removedItem, animation: animation),
          duration: AppMotion.normal,
        );
      }
    }

    for (final id in next.keys) {
      if (_snapshot.containsKey(id)) {
        _snapshot[id] = next[id]!;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Map<String, CartItem>>(cartProvider, (previous, next) {
      setState(() => _syncCart(next));
    });

    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final gutter = AppSpacing.gutterFor(MediaQuery.sizeOf(context).width);

    return AnimatedSwitcher(
      duration: AppMotion.normal,
      child: _order.isEmpty
          ? EmptyState(
              key: const ValueKey('empty'),
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Add a few items from the store and they\'ll show up here.',
              action: FilledButton(
                onPressed: () => ref.read(homeTabIndexProvider.notifier).state = 0,
                child: const Text('Start shopping'),
              ),
            )
          : Column(
              key: const ValueKey('items'),
              children: [
                Expanded(
                  child: AnimatedList(
                    key: _listKey,
                    padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, AppSpacing.md),
                    initialItemCount: _order.length,
                    itemBuilder: (context, index, animation) {
                      final id = _order[index];
                      final item = cart[id] ?? _snapshot[id]!;
                      return _CartRow(item: item, animation: animation);
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
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
                                    style: Theme.of(context).textTheme.bodyMedium),
                              ),
                              Text(
                                currency.format(notifier.totalPrice),
                                style: Theme.of(context).textTheme.titleLarge,
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
            ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final CartItem item;
  final Animation<double> animation;
  const _CartRow({required this.item, required this.animation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return SizeTransition(
      sizeFactor: animation,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Card(
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
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 112,
                    child: AnimatedQuantityStepper(product: item.product),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
