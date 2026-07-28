// lib/features/admin/products/admin_products_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../../shared/widgets/app_states.dart';
import 'admin_product_service.dart';
import 'admin_products_provider.dart';
import 'edit_product_screen.dart';

class AdminProductsScreen extends ConsumerWidget {
  const AdminProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(adminCatalogProvider);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final gutter = AppSpacing.gutterFor(MediaQuery.sizeOf(context).width);

    return catalogAsync.when(
      loading: () => const ListSkeleton(itemHeight: 76),
      error: (e, _) => ErrorState(
        title: 'Could not load products',
        error: e,
        onRetry: () => ref.invalidate(adminCatalogProvider),
      ),
      data: (catalog) {
        final outOfStock = catalog.products.where((p) => !p.isAvailable).length;

        return Scaffold(
          body: catalog.products.isEmpty
              ? EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No products yet',
                  message: 'Add your first product to start selling.',
                  action: FilledButton.icon(
                    onPressed: () => _openEditor(context, catalog),
                    icon: const Icon(Icons.add, size: AppIconSize.md),
                    label: const Text('Add product'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.refresh(adminCatalogProvider.future),
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, 96),
                    itemCount: catalog.products.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _StockSummary(
                          total: catalog.products.length,
                          outOfStock: outOfStock,
                        );
                      }
                      final product = catalog.products[index - 1];
                      return _AdminProductTile(
                        key: ValueKey(product.id),
                        product: product,
                        currency: currency,
                        categories: catalog.categories,
                      );
                    },
                  ),
                ),
          floatingActionButton: catalog.products.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openEditor(context, catalog),
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                ),
        );
      },
    );
  }

  void _openEditor(BuildContext context, AdminCatalogData catalog) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProductScreen(categories: catalog.categories),
      ),
    );
  }
}

class _StockSummary extends StatelessWidget {
  final int total;
  final int outOfStock;
  const _StockSummary({required this.total, required this.outOfStock});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            '$total product${total == 1 ? '' : 's'}',
            style: theme.textTheme.bodyMedium?.copyWith(color: semantic.mutedText),
          ),
          if (outOfStock > 0) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: semantic.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$outOfStock hidden from customers',
                style: theme.textTheme.labelSmall?.copyWith(color: semantic.warning),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminProductTile extends ConsumerWidget {
  final Product product;
  final NumberFormat currency;
  final List<Category> categories;

  const _AdminProductTile({
    super.key,
    required this.product,
    required this.currency,
    required this.categories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final isGrocery = product.productType == 'grocery';

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditProductScreen(
                categories: categories,
                existing: product,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              _Thumbnail(product: product),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        Icon(
                          isGrocery
                              ? Icons.shopping_basket_outlined
                              : Icons.eco_outlined,
                          size: AppIconSize.sm,
                          color: isGrocery ? semantic.grocery : semantic.fruitVeg,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            '${product.unit} · ${currency.format(product.price)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: semantic.mutedText),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Label makes the switch's meaning explicit — a bare toggle
              // doesn't say what it controls.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: product.isAvailable,
                    onChanged: (value) {
                      ref
                          .read(adminProductServiceProvider)
                          .setAvailability(product.id, value);
                    },
                  ),
                  Text(
                    product.isAvailable ? 'In stock' : 'Hidden',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: product.isAvailable
                          ? semantic.success
                          : semantic.mutedText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final Product product;
  const _Thumbnail({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget frame(Widget child) => ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(width: 52, height: 52, child: child),
        );

    if (product.imageUrl == null) {
      return frame(
        ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.image_outlined,
            size: AppIconSize.md,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return frame(
      CachedNetworkImage(
        imageUrl: product.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => const SkeletonBox(height: 52, radius: 0),
        errorWidget: (_, __, ___) => ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.image_not_supported_outlined,
            size: AppIconSize.md,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
