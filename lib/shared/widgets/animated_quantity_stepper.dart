// lib/shared/widgets/animated_quantity_stepper.dart
//
// The add-to-cart control: an "Add" button that cross-fades into a -/+
// stepper once the product is in the cart. Extracted out of product_card.dart
// so the grid tile and product_detail_sheet.dart (Phase 3) share one
// implementation instead of two copies drifting apart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/cart/cart_provider.dart';
import '../../models/product.dart';
import 'fly_to_cart_overlay.dart';

class AnimatedQuantityStepper extends ConsumerWidget {
  final Product product;
  const AnimatedQuantityStepper({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(
      cartProvider.select((cart) => cart[product.id]?.quantity ?? 0),
    );
    final inCart = quantity > 0;

    // Add <-> stepper cross-fades, and both are kMinTapTarget tall so the
    // swap never shifts surrounding layout.
    return AnimatedSwitcher(
      duration: AppMotion.fast,
      child: inCart
          ? _Stepper(
              key: const ValueKey('stepper'),
              product: product,
              quantity: quantity,
            )
          : _AddButton(
              key: const ValueKey('add'),
              product: product,
            ),
    );
  }
}

class _AddButton extends ConsumerWidget {
  final Product product;
  const _AddButton({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return _Bouncy(
      onTap: () {
        flyToCart(
          sourceContext: context,
          targetKey: ref.read(cartIconKeyProvider),
          imageUrl: product.imageUrl,
        );
        ref.read(cartProvider.notifier).add(product);
      },
      child: Container(
        height: kMinTapTarget,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Semantics(
          label: 'Add ${product.name} to cart',
          excludeSemantics: true,
          child: Text(
            'Add',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Scales down on tap-down and springs back on release — used by `_AddButton`
/// and `_StepperButton` so quick-add taps feel physical rather than instant.
class _Bouncy extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Bouncy({required this.child, required this.onTap});

  @override
  State<_Bouncy> createState() => _BouncyState();
}

class _BouncyState extends State<_Bouncy> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.85 : 1.0,
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _Stepper extends ConsumerWidget {
  final Product product;
  final int quantity;
  const _Stepper({super.key, required this.product, required this.quantity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      height: kMinTapTarget,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: theme.colorScheme.primary),
      ),
      child: Row(
        children: [
          _StepperButton(
            icon: Icons.remove,
            // Label reflects what the button will actually do.
            semanticLabel: quantity > 1
                ? 'Remove one ${product.name}'
                : 'Remove ${product.name} from cart',
            onPressed: () => ref.read(cartProvider.notifier).remove(product),
          ),
          Expanded(
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            semanticLabel: 'Add one more ${product.name}',
            onPressed: () {
              flyToCart(
                sourceContext: context,
                targetKey: ref.read(cartIconKeyProvider),
                imageUrl: product.imageUrl,
              );
              ref.read(cartProvider.notifier).add(product);
            },
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  const _StepperButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: _Bouncy(
        onTap: onPressed,
        // A real 48x48dp target — this is the smallest control in the app and
        // it gets tapped repeatedly, so it can't be undersized.
        child: SizedBox(
          width: kMinTapTarget,
          height: kMinTapTarget,
          child: Icon(
            icon,
            size: AppIconSize.md,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
