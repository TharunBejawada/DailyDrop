// lib/shared/widgets/offline_banner.dart
//
// Ties connectivity_plus (already a dependency, unused for UI until now) to
// an actual banner. Mounted once at the CustomerHomeShell/AdminHomeScreen
// level rather than duplicated into every individual tab screen, since both
// shells already own a single Scaffold their tabs swap inside.

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

/// Emits the current online/offline state immediately (via an initial
/// check), then follows `onConnectivityChanged` for updates.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  yield isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(isOnline);
});

/// Grows/shrinks in place at the top of a shell's body — no reserved space
/// when online, so it never pushes other transient banners (e.g. the admin
/// new-order alert) down by a phantom gap.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;

    return AnimatedSize(
      duration: AppMotion.normal,
      alignment: Alignment.topCenter,
      child: isOnline
          ? const SizedBox.shrink()
          : const SizedBox(width: double.infinity, child: _BannerContent()),
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: semantic.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: semantic.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: AppIconSize.md, color: semantic.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                "You're offline — showing saved data",
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: semantic.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
