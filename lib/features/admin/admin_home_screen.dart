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
  NewOrderAlert? _pendingAlert;
  bool _bannerVisible = false;

  Future<void> _showBanner(NewOrderAlert alert) async {
    setState(() {
      _pendingAlert = alert;
      _bannerVisible = true;
    });
    await Future.delayed(const Duration(seconds: 6));
    if (!mounted || _pendingAlert != alert) return;
    setState(() => _bannerVisible = false);
  }

  void _viewFromBanner() {
    setState(() {
      _tabIndex = 0;
      _unseenOrders = 0;
      _bannerVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    // Fires every time a new order lands, regardless of which tab is open.
    ref.listen<AsyncValue<NewOrderAlert>>(newOrderAlertProvider,
        (previous, next) {
      next.whenData((alert) {
        SystemSound.play(SystemSoundType.alert);

        if (_tabIndex != 0) {
          setState(() => _unseenOrders++);
        }

        _showBanner(alert);
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
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: semantic.mutedText),
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
      body: Stack(
        children: [
          screens[_tabIndex],
          if (_pendingAlert != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                duration: AppMotion.normal,
                curve: Curves.easeOutBack,
                offset: _bannerVisible ? Offset.zero : const Offset(0, -1.2),
                child: AnimatedOpacity(
                  duration: AppMotion.normal,
                  opacity: _bannerVisible ? 1 : 0,
                  child: _NewOrderBanner(
                    text:
                        'New ${OrderTypeChip.labelFor(_pendingAlert!.orderType)} '
                        'order — ${currency.format(_pendingAlert!.totalAmount)}',
                    onView: _viewFromBanner,
                  ),
                ),
              ),
            ),
        ],
      ),
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

/// New-order alert, slid/faded in by the `AnimatedSlide`/`AnimatedOpacity`
/// pair in `_AdminHomeScreenState.build` — replaces what used to be a plain
/// SnackBar so it reads while other tabs are open without stealing focus.
class _NewOrderBanner extends StatelessWidget {
  final String text;
  final VoidCallback onView;
  const _NewOrderBanner({required this.text, required this.onView});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Material(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    size: AppIconSize.md, color: theme.colorScheme.onPrimary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onPrimary),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onPrimary),
                  onPressed: onView,
                  child: const Text('View'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
