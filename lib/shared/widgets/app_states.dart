// lib/shared/widgets/app_states.dart
//
// Shared loading / empty / error states. Previously every screen spun its own
// bare CircularProgressIndicator and raw "Could not load: $err" text; these
// give all of them the same shape, spacing and tone.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

/// Grey skeleton block. Static on its own — `ProductGridSkeleton`/
/// `ListSkeleton` wrap a whole batch of these in one `Shimmer.fromColors`
/// sweep rather than each box animating independently, which reads as one
/// coherent "loading" surface instead of a field of separately-pulsing tiles.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Wraps skeleton content in a shimmer sweep, unless the platform/user has
/// requested reduced motion — in which case the static grey boxes alone
/// already read as "loading" without the animation.
class _ShimmerSweep extends StatelessWidget {
  final Widget child;
  const _ShimmerSweep({required this.child});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ??
        MediaQuery.maybeOf(context)?.disableAnimations ??
        false;
    if (reduceMotion) return child;

    final theme = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surface,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// Skeleton grid matching the product-card layout, so the catalog reserves
/// the same space it will fill (no layout shift when data lands).
class ProductGridSkeleton extends StatelessWidget {
  final int count;
  const ProductGridSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpacing.gutterFor(MediaQuery.sizeOf(context).width);
    return _ShimmerSweep(
      child: GridView.builder(
        padding: EdgeInsets.all(gutter),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.7,
        ),
        itemCount: count,
        itemBuilder: (context, index) => const Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: SkeletonBox(height: double.infinity, radius: 0),
              ),
              Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 12),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonBox(height: 10, width: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton list for order/product lists.
class ListSkeleton extends StatelessWidget {
  final int count;
  final double itemHeight;
  const ListSkeleton({super.key, this.count = 4, this.itemHeight = 96});

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpacing.gutterFor(MediaQuery.sizeOf(context).width);
    return _ShimmerSweep(
      child: ListView.separated(
        padding: EdgeInsets.all(gutter),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, __) => SkeletonBox(
          height: itemHeight,
          radius: AppRadius.lg,
        ),
      ),
    );
  }
}

/// Friendly empty state: icon in a tinted circle, headline, supporting line,
/// optional action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: AppIconSize.hero,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: semantic.mutedText),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error state with a retry affordance. Keeps the raw error available but
/// de-emphasised, so the user sees a plain-language line first.
class ErrorState extends StatelessWidget {
  final String title;
  final Object? error;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: AppIconSize.hero,
                color: semantic.danger,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: semantic.mutedText),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.xl),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: AppIconSize.md),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
