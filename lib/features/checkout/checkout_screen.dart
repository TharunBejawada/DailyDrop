// lib/features/checkout/checkout_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/supabase_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/status_badge.dart';
import '../addresses/address_provider.dart';
import '../cart/cart_provider.dart';
import '../home/home_tab_provider.dart';
import 'delivery_slot.dart';
import 'order_service.dart';
import 'razorpay_service.dart';

/// Drives the "Place order" button's morph and the full-bleed confirmation.
/// `success` is a brief hold (see `_showSuccessAndFinish`) before the screen
/// navigates away — not a persisted state.
enum _PlaceOrderState { idle, placing, success }

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _selectedAddressId;
  // Web has no Razorpay support, so it defaults to (and stays on) COD.
  String _paymentMethod = kIsWeb ? 'cod' : 'upi';
  _PlaceOrderState _orderState = _PlaceOrderState.idle;
  final _razorpayService = RazorpayService();

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  Future<void> _showAddAddressDialog() async {
    final labelController = TextEditingController();
    final landmarkController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add delivery address'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    helperText: 'e.g. Home, Office',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: landmarkController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Landmark / address',
                    helperText: 'e.g. Near XYZ temple, Main Road',
                  ),
                  // Validation is inline and next to the field, not a silent
                  // no-op on Save like before.
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter an address'
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Contact phone number'),
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'Enter a valid 10-digit number'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await ref.read(addressServiceProvider).addAddress(
                    label: labelController.text.trim().isEmpty
                        ? 'Address'
                        : labelController.text.trim(),
                    landmark: landmarkController.text.trim(),
                    phone: phoneController.text.trim(),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    labelController.dispose();
    landmarkController.dispose();
    phoneController.dispose();
  }

  Future<void> _placeOrder() async {
    if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address')),
      );
      return;
    }

    setState(() => _orderState = _PlaceOrderState.placing);
    final cart = ref.read(cartProvider);
    final totalAmount =
        cart.values.fold(0.0, (sum, item) => sum + item.subtotal);

    try {
      final orderIds = await ref.read(orderServiceProvider).placeOrder(
            cart: cart,
            addressId: _selectedAddressId!,
            paymentMethod: _paymentMethod,
          );

      if (_paymentMethod == 'cod') {
        await _showSuccessAndFinish();
        return;
      }

      // UPI: orders already exist with payment_status = 'pending'. Open
      // Razorpay for the combined total; on success, mark each of those
      // orders paid via the narrow mark_order_paid RPC.
      final addresses = await ref.read(addressesProvider.future);
      final address = addresses.firstWhere((a) => a.id == _selectedAddressId);

      _razorpayService.open(
        amountRupees: totalAmount,
        contactPhone: address.phone,
        onSuccess: (PaymentSuccessResponse response) async {
          for (final orderId in orderIds) {
            await supabase
                .rpc('mark_order_paid', params: {'order_id': orderId});
          }
          await _showSuccessAndFinish();
        },
        onError: (PaymentFailureResponse response) {
          // Orders already exist (payment_status stays 'pending') — nothing
          // to roll back. Let the customer know clearly what happened.
          if (mounted) {
            setState(() => _orderState = _PlaceOrderState.idle);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Order placed, but payment did not go through (${response.message}). '
                    'You can pay on delivery, or contact the store.'),
                duration: const Duration(seconds: 6),
              ),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
      );
    } on Object catch (e) {
      if (mounted) {
        setState(() => _orderState = _PlaceOrderState.idle);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not place order: $e')));
      }
    }
  }

  /// Holds on a full-bleed checkmark (see `_OrderSuccessOverlay`) just long
  /// enough to read as a confirmation, then runs the existing navigation.
  /// Replaces what used to be an instant SnackBar-and-pop.
  Future<void> _showSuccessAndFinish() async {
    if (!mounted) return;
    setState(() => _orderState = _PlaceOrderState.success);
    await Future.delayed(AppMotion.slow * 3);
    if (!mounted) return;
    _finishCheckout();
  }

  void _finishCheckout() {
    ref.read(cartProvider.notifier).clear();
    if (mounted) {
      // Jump to the Orders tab so the new order's tracker is right there —
      // matches how Blinkit/Zepto confirm a placed order.
      ref.read(homeTabIndexProvider.notifier).state = 2;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final cart = ref.watch(cartProvider);
    final addressesAsync = ref.watch(addressesProvider);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final gutter = AppSpacing.gutterFor(MediaQuery.sizeOf(context).width);

    final items = cart.values.toList();
    final hasGrocery = items.any((i) => i.product.productType == 'grocery');
    final hasFruitVeg = items.any((i) => i.product.productType == 'fruit_veg');
    final orderType = hasGrocery && hasFruitVeg
        ? 'mixed'
        : (hasFruitVeg ? 'fruit_veg' : 'grocery');
    final total = cart.values.fold(0.0, (sum, item) => sum + item.subtotal);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: 'Your cart is empty',
          message: 'Add a few items and come back to check out.',
          action: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to shopping'),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Checkout')),
          body: ListView(
            padding:
                EdgeInsets.fromLTRB(gutter, gutter, gutter, AppSpacing.xxl),
            children: [
              _OrderGroupSummary(
                orderType: orderType,
                slotLabel: deliverySlot().label,
                items: items,
                currency: currency,
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle(
                icon: Icons.location_on_outlined,
                title: 'Delivery address',
              ),
              const SizedBox(height: AppSpacing.md),
              addressesAsync.when(
                loading: () => const ListSkeleton(count: 2, itemHeight: 64),
                error: (e, _) => ErrorState(
                  title: 'Could not load your addresses',
                  error: e,
                  onRetry: () => ref.invalidate(addressesProvider),
                ),
                data: (addresses) {
                  _selectedAddressId ??=
                      addresses.isNotEmpty ? addresses.first.id : null;

                  if (addresses.isEmpty) {
                    return _Callout(
                      icon: Icons.add_location_alt_outlined,
                      color: semantic.warning,
                      text: 'Add a delivery address to continue.',
                      action: TextButton(
                        onPressed: _showAddAddressDialog,
                        child: const Text('Add address'),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final address in addresses)
                        _SelectableTile(
                          selected: _selectedAddressId == address.id,
                          onTap: () =>
                              setState(() => _selectedAddressId = address.id),
                          title: address.label,
                          subtitle: '${address.landmark}\n${address.phone}',
                          leading: Icons.location_on_outlined,
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _showAddAddressDialog,
                          icon: const Icon(Icons.add, size: AppIconSize.md),
                          label: const Text('Add new address'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle(
                icon: Icons.payments_outlined,
                title: 'Payment method',
              ),
              const SizedBox(height: AppSpacing.md),
              if (!kIsWeb)
                _SelectableTile(
                  selected: _paymentMethod == 'upi',
                  onTap: () => setState(() => _paymentMethod = 'upi'),
                  title: 'UPI / Card',
                  subtitle: 'Pay now, securely via Razorpay',
                  leading: Icons.account_balance_wallet_outlined,
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _Callout(
                    icon: Icons.info_outline,
                    color: semantic.mutedText,
                    text: 'Online payment is available on the Android app. '
                        'On web, Cash on Delivery only for now.',
                  ),
                ),
              _SelectableTile(
                selected: _paymentMethod == 'cod',
                onTap: () => setState(() => _paymentMethod = 'cod'),
                title: 'Cash on Delivery',
                subtitle: 'Pay the delivery partner when your order arrives',
                leading: Icons.currency_rupee,
              ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant)),
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
                          child: Text('Total payable',
                              style: theme.textTheme.bodyMedium),
                        ),
                        Text(
                          currency.format(total),
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _orderState == _PlaceOrderState.idle
                          ? _placeOrder
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: AnimatedSwitcher(
                        duration: AppMotion.fast,
                        child: switch (_orderState) {
                          _PlaceOrderState.idle => Text(
                              _paymentMethod == 'cod'
                                  ? 'Place order'
                                  : 'Pay ${currency.format(total)}',
                              key: const ValueKey('idle'),
                            ),
                          _PlaceOrderState.placing => SizedBox(
                              key: const ValueKey('placing'),
                              height: AppIconSize.md,
                              width: AppIconSize.md,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          _PlaceOrderState.success => Icon(
                              Icons.check_rounded,
                              key: const ValueKey('success'),
                              color: theme.colorScheme.onPrimary,
                              size: AppIconSize.md,
                            ),
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_orderState == _PlaceOrderState.success)
          const Positioned.fill(child: _OrderSuccessOverlay()),
      ],
    );
  }
}

/// Full-bleed confirmation shown for a brief hold after a successful order
/// (see `_showSuccessAndFinish`) — replaces the old instant SnackBar.
class _OrderSuccessOverlay extends StatelessWidget {
  const _OrderSuccessOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: AppIconSize.hero,
              color: theme.colorScheme.onPrimary,
            )
                .animate()
                .scale(
                  begin: const Offset(0.4, 0.4),
                  end: const Offset(1, 1),
                  duration: AppMotion.slow,
                  curve: Curves.elasticOut,
                )
                .fadeIn(duration: AppMotion.fast),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Order placed!',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            )
                .animate(delay: AppMotion.normal)
                .fadeIn(duration: AppMotion.normal),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.md, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(title, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

/// Tappable selection row. Replaces RadioListTile so the whole card is the
/// (48dp+) target and the selected state reads at a glance.
class _SelectableTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final IconData leading;

  const _SelectableTile({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              constraints: const BoxConstraints(minHeight: kMinTapTarget),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    leading,
                    size: AppIconSize.lg,
                    color: selected
                        ? theme.colorScheme.primary
                        : semantic.mutedText,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: semantic.mutedText),
                        ),
                      ],
                    ),
                  ),
                  // Icon + fill + border together — not colour alone.
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: AppIconSize.md,
                    color: selected
                        ? theme.colorScheme.primary
                        : semantic.mutedText,
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

class _Callout extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final Widget? action;

  const _Callout({
    required this.icon,
    required this.color,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIconSize.md, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text, style: theme.textTheme.bodySmall),
                if (action != null) action!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderGroupSummary extends StatelessWidget {
  final String orderType;
  final String slotLabel;
  final List<CartItem> items;
  final NumberFormat currency;

  const _OrderGroupSummary({
    required this.orderType,
    required this.slotLabel,
    required this.items,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final total = items.fold(0.0, (sum, item) => sum + item.subtotal);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OrderTypeChip(orderType: orderType),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.schedule_outlined,
                    size: AppIconSize.sm, color: semantic.mutedText),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    slotLabel,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: semantic.mutedText),
                  ),
                ),
              ],
            ),
            const Divider(),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.product.name} × ${item.quantity}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      currency.format(item.subtotal),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text('Subtotal', style: theme.textTheme.bodyMedium),
                ),
                Text(currency.format(total), style: theme.textTheme.titleSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
