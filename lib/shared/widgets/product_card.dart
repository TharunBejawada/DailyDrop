// lib/shared/widgets/product_card.dart
//
// Uses ref.watch(...select...) so ONLY this card rebuilds when its own
// quantity changes — not the whole grid. Matters once the catalog grows.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../features/cart/cart_provider.dart';
import '../../features/catalog/product_detail_sheet.dart';
import '../../models/product.dart';
import 'animated_quantity_stepper.dart';
import 'app_states.dart';

class ProductCard extends ConsumerWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(
      cartProvider.select((cart) => cart[product.id]?.quantity ?? 0),
    );
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final inCart = quantity > 0;

    return Card(
      // Cards in the cart get a primary-tinted outline: a second, non-colour
      // cue (the stepper) already exists, this just makes it scannable.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: inCart ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          width: inCart ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => showProductDetailSheet(context, product),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: productImageHeroTag(product.id),
                    child: _ProductImage(product: product),
                  ),
                  if (inCart)
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: _QuantityPip(quantity: quantity),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  product.unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: semantic.mutedText),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  currency.format(product.price),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                // The control gets its own full-width row rather than sharing
                // one with the price: at 2 columns on a 375px phone there
                // isn't room for a 48dp-tall stepper beside text.
                AnimatedQuantityStepper(product: product),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final Product product;
  const _ProductImage({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholderBg = theme.colorScheme.surfaceContainerHighest;

    Widget fallback(IconData icon) => ColoredBox(
          color: placeholderBg,
          child: Center(
            child: Icon(
              icon,
              size: AppIconSize.xl,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );

    if (product.imageUrl == null) {
      // Decorative only — the product name is already announced as text.
      return ExcludeSemantics(child: fallback(Icons.shopping_basket_outlined));
    }

    return ExcludeSemantics(
      child: CachedNetworkImage(
        imageUrl: product.imageUrl!,
        fit: BoxFit.cover,
        fadeInDuration: AppMotion.fast,
        placeholder: (_, __) => const SkeletonBox(
          height: double.infinity,
          radius: 0,
        ),
        errorWidget: (_, __, ___) => fallback(Icons.image_not_supported_outlined),
      ),
    );
  }
}

/// Quantity marker over the image — reinforces "in cart" beyond the outline.
class _QuantityPip extends StatelessWidget {
  final int quantity;
  const _QuantityPip({required this.quantity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$quantity in cart',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

