// lib/features/home/customer_home_shell.dart
//
// The customer-facing root screen (both guest and signed-in) — mirrors
// AdminHomeScreen's bottom-nav-shell pattern: one Scaffold, one AppBar, body
// swaps between tabs by index, no Navigator.push between them. Login is
// only enforced inside individual tabs/actions (see core/auth_guard.dart),
// not by the shell itself.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../account/account_screen.dart';
import '../addresses/address_provider.dart';
import '../auth/login_screen.dart';
import '../cart/cart_provider.dart';
import '../cart/cart_screen.dart';
import '../catalog/catalog_screen.dart';
import '../orders/customer_orders_screen.dart';
import 'home_tab_provider.dart';

class CustomerHomeShell extends ConsumerWidget {
  const CustomerHomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = ref.watch(homeTabIndexProvider);
    final isGuest = supabase.auth.currentSession == null;
    final cartCount = ref.watch(cartProvider.select((c) =>
        c.values.fold(0, (sum, item) => sum + item.quantity)));

    const titles = ['DailyDrop', 'Your cart', 'Your orders', 'Account'];
    const screens = [
      CatalogScreen(),
      CartScreen(),
      CustomerOrdersScreen(),
      AccountScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: tabIndex == 0
            ? const _DeliveryHeader()
            : Text(titles[tabIndex]),
        actions: [
          if (isGuest && tabIndex != 3)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                icon: const Icon(Icons.login_outlined, size: AppIconSize.sm),
                label: const Text('Sign in'),
              ),
            ),
        ],
      ),
      body: screens[tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: (i) => ref.read(homeTabIndexProvider.notifier).state = i,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('$cartCount'),
              isLabelVisible: cartCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: Badge(
              label: Text('$cartCount'),
              isLabelVisible: cartCount > 0,
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

/// Compact "deliver to X, same-day" header replacing the plain subtitle —
/// this app has no location/GPS integration, so it shows the signed-in
/// user's default saved address (or a generic prompt for guests) rather
/// than a real detected location.
class _DeliveryHeader extends ConsumerWidget {
  const _DeliveryHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final isGuest = supabase.auth.currentSession == null;

    final addressLabel = isGuest
        ? null
        : ref.watch(addressesProvider).maybeWhen(
              data: (addresses) => addresses.isNotEmpty ? addresses.first.landmark : null,
              orElse: () => null,
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: AppIconSize.sm, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: Text(
                addressLabel ?? (isGuest ? 'Browsing as guest' : 'Add a delivery address'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: semantic.mutedText),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text('DailyDrop', style: theme.textTheme.titleLarge),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: semantic.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, size: AppIconSize.sm, color: semantic.success),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    '30–45 min',
                    style: theme.textTheme.labelSmall?.copyWith(color: semantic.success),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
