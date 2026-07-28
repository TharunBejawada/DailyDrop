// lib/features/catalog/catalog_screen.dart
//
// This is the Home tab's body inside CustomerHomeShell — it owns no
// Scaffold/AppBar of its own (the shell provides those, plus the delivery
// header and the persistent bottom nav). Search field + grocery/fruit-veg
// tabs + product grid + the floating "go to cart" bar all live here.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../cart/cart_provider.dart';
import '../home/home_tab_provider.dart';
import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/section_header.dart';
import 'catalog_providers.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const _SearchField(),
          ColoredBox(
            color: theme.colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(
                  height: 52,
                  icon: Icon(Icons.shopping_basket_outlined, size: AppIconSize.md),
                  iconMargin: EdgeInsets.only(bottom: AppSpacing.xxs),
                  text: 'Grocery',
                ),
                Tab(
                  height: 52,
                  icon: Icon(Icons.eco_outlined, size: AppIconSize.md),
                  iconMargin: EdgeInsets.only(bottom: AppSpacing.xxs),
                  text: 'Fruits & Veg',
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _CatalogTab(productType: 'grocery'),
                _CatalogTab(productType: 'fruit_veg'),
              ],
            ),
          ),
          const _CartBar(),
        ],
      ),
    );
  }
}

class _SearchField extends ConsumerWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gutter = AppSpacing.gutterFor(MediaQuery.sizeOf(context).width);
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, AppSpacing.sm),
      child: TextField(
        onChanged: (v) => ref.read(catalogSearchQueryProvider.notifier).state = v,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'Search groceries, fruits & veg…',
          prefixIcon: Icon(Icons.search, size: AppIconSize.md),
        ),
      ),
    );
  }
}

class _CatalogTab extends ConsumerWidget {
  final String productType;
  const _CatalogTab({required this.productType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);
    final cartIsEmpty = ref.watch(cartProvider).isEmpty;
    final query = ref.watch(catalogSearchQueryProvider).trim();

    // Reserve room so the last row isn't hidden behind the floating cart bar.
    final bottomInset = cartIsEmpty ? AppSpacing.xl : 96.0;

    return catalogAsync.when(
      loading: () => const ProductGridSkeleton(),
      error: (err, _) => ErrorState(
        title: 'Could not load products',
        error: err,
        onRetry: () => ref.invalidate(catalogProvider),
      ),
      data: (catalog) {
        final categories =
            catalog.categories.where((c) => c.productType == productType).toList();
        final hasAnyProduct = categories
            .any((c) => _filtered(catalog.productsForCategory(c.id), query).isNotEmpty);

        return RefreshIndicator(
          onRefresh: () => ref.refresh(catalogProvider.future),
          child: CustomScrollView(
            slivers: [
              if (!hasAnyProduct)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: query.isNotEmpty
                      ? EmptyState(
                          icon: Icons.search_off_outlined,
                          title: 'No matches',
                          message: 'Nothing found for "$query". Try a different search.',
                        )
                      : EmptyState(
                          icon: productType == 'grocery'
                              ? Icons.shopping_basket_outlined
                              : Icons.eco_outlined,
                          title: 'Nothing here yet',
                          message: productType == 'grocery'
                              ? 'The store hasn\'t added grocery items yet. Pull down to refresh.'
                              : 'No fruits or vegetables listed right now. Pull down to refresh.',
                        ),
                )
              else
                for (final category in categories)
                  ..._categorySlivers(context, category, catalog, query),
              SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
            ],
          ),
        );
      },
    );
  }

  static List<Product> _filtered(List<Product> products, String query) {
    if (query.isEmpty) return products;
    final q = query.toLowerCase();
    return products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  List<Widget> _categorySlivers(
    BuildContext context,
    Category category,
    CatalogData catalog,
    String query,
  ) {
    final products = _filtered(catalog.productsForCategory(category.id), query);
    if (products.isEmpty) return const [];

    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: category.name,
          trailing: '${products.length} item${products.length == 1 ? '' : 's'}',
        ),
      ),
      _ProductGrid(products: products),
    ];
  }
}

class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  const _ProductGrid({required this.products});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = AppSpacing.gutterFor(width);
    // Widen the grid on larger screens instead of stretching two huge cards.
    final columns = width >= 1000
        ? 5
        : width >= 720
            ? 4
            : width >= 520
                ? 3
                : 2;

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.66,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => ProductCard(
            // Key by id so cards keep identity as the list changes.
            key: ValueKey(products[index].id),
            product: products[index],
          )
              // Staggered entrance on first load / tab switch / search filter
              // — capped delay so a long grid doesn't make the tail wait ages.
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: 25 * index.clamp(0, 12)),
                duration: AppMotion.normal,
              )
              .slideY(
                begin: 0.08,
                end: 0,
                delay: Duration(milliseconds: 25 * index.clamp(0, 12)),
                duration: AppMotion.normal,
                curve: Curves.easeOutCubic,
              ),
          childCount: products.length,
        ),
      ),
    );
  }
}

/// Floating summary bar. Animates in from the bottom when the cart becomes
/// non-empty rather than popping into existence. Tapping it switches the
/// shell to the Cart tab for review, rather than jumping straight to
/// checkout.
class _CartBar extends ConsumerWidget {
  const _CartBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final notifier = ref.read(cartProvider.notifier);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final isEmpty = cart.isEmpty;

    final totalItems = notifier.totalItems;
    final totalPrice = notifier.totalPrice;

    return AnimatedSlide(
      offset: isEmpty ? const Offset(0, 1) : Offset.zero,
      duration: AppMotion.normal,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isEmpty ? 0 : 1,
        duration: AppMotion.fast,
        // Fully hidden from the tree (and from screen readers) when empty.
        child: isEmpty
            ? const SizedBox(height: 0)
            : Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(
                            Icons.shopping_cart_outlined,
                            size: AppIconSize.md,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: AppMotion.fast,
                                child: Text(
                                  '$totalItems item${totalItems == 1 ? '' : 's'}',
                                  key: ValueKey(totalItems),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppSemantic.of(context).mutedText,
                                  ),
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: AppMotion.fast,
                                transitionBuilder: (child, animation) => FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.3),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                                child: Text(
                                  currency.format(totalPrice),
                                  key: ValueKey(totalPrice),
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () =>
                              ref.read(homeTabIndexProvider.notifier).state = 1,
                          icon: const Icon(Icons.arrow_forward, size: AppIconSize.md),
                          iconAlignment: IconAlignment.end,
                          label: const Text('View cart'),
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
