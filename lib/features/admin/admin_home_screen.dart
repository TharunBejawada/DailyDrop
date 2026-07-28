// lib/features/admin/admin_home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/status_badge.dart';
import '../auth/auth_service.dart';
import 'orders/admin_orders_screen.dart';
import 'orders/order_realtime_service.dart';
import 'products/admin_products_screen.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _tabIndex = 0;
  int _unseenOrders = 0;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    // Snackbars use an inverted surface, so the icon has to match the snackbar's
    // own text color rather than the page foreground.
    final onSnackBar = Theme.of(context).snackBarTheme.contentTextStyle?.color;

    // Fires every time a new order lands, regardless of which tab is open.
    ref.listen<AsyncValue<NewOrderAlert>>(newOrderAlertProvider, (previous, next) {
      next.whenData((alert) {
        SystemSound.play(SystemSoundType.alert);

        if (_tabIndex != 0) {
          setState(() => _unseenOrders++);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    size: AppIconSize.md, color: onSnackBar),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'New ${OrderTypeChip.labelFor(alert.orderType)} '
                    'order — ${currency.format(alert.totalAmount)}',
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'View',
              onPressed: () => setState(() {
                _tabIndex = 0;
                _unseenOrders = 0;
              }),
            ),
          ),
        );
      });
    });

    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final titles = ['Order queue', 'Products'];
    final screens = [const AdminOrdersScreen(), const AdminProductsScreen()];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles[_tabIndex], style: theme.textTheme.titleLarge),
            Text(
              'Store admin',
              style: theme.textTheme.bodySmall?.copyWith(color: semantic.mutedText),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: screens[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() {
          _tabIndex = i;
          if (i == 0) _unseenOrders = 0;
        }),
        destinations: [
          NavigationDestination(
            icon: Badge(
              label: Text('$_unseenOrders'),
              isLabelVisible: _unseenOrders > 0,
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: Badge(
              label: Text('$_unseenOrders'),
              isLabelVisible: _unseenOrders > 0,
              child: const Icon(Icons.receipt_long),
            ),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
        ],
      ),
    );
  }
}