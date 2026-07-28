// lib/features/catalog/product_detail_sheet.dart
//
// Tapping a product's image opens this instead of pushing a full screen —
// matches how Zepto/Blinkit actually behave: quick-add on the grid stays the
// fast path, and this detail view is opt-in. The image Hero-flies in from
// the grid tile (see productImageHeroTag), and the sheet itself drags to
// dismiss via DraggableScrollableSheet rather than needing an explicit close
// button.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product.dart';
import '../../shared/widgets/animated_quantity_stepper.dart';

/// Shared between the grid tile (product_card.dart) and this sheet so the
/// Hero flight has a matching tag on both ends.
String productImageHeroTag(String productId) => 'product-image-$productId';

void showProductDetailSheet(BuildContext context, Product product) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProductDetailSheet(product: product),
  );
}

class ProductDetailSheet extends StatelessWidget {
  final Product product;
  const ProductDetailSheet({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              AspectRatio(
                aspectRatio: 1.3,
                child: Hero(
                  tag: productImageHeroTag(product.id),
                  child: _DetailImage(product: product),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      product.unit,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: semantic.mutedText),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currency.format(product.price),
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(
                          width: 140,
                          child: AnimatedQuantityStepper(product: product),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailImage extends StatelessWidget {
  final Product product;
  const _DetailImage({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholderBg = theme.colorScheme.surfaceContainerHighest;

    Widget fallback(IconData icon) => ColoredBox(
          color: placeholderBg,
          child: Center(
            child: Icon(
              icon,
              size: AppIconSize.hero,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );

    if (product.imageUrl == null) {
      return fallback(Icons.shopping_basket_outlined);
    }

    return CachedNetworkImage(
      imageUrl: product.imageUrl!,
      fit: BoxFit.cover,
      fadeInDuration: AppMotion.fast,
      placeholder: (_, __) => fallback(Icons.image_outlined),
      errorWidget: (_, __, ___) => fallback(Icons.image_not_supported_outlined),
    );
  }
}
