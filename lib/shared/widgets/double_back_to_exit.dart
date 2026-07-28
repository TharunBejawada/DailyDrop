// lib/shared/widgets/double_back_to_exit.dart
//
// Wraps a "root" screen (nothing else pushed on top) so the Android back
// button needs a second press within 2s to actually exit, instead of
// closing the app on the first tap. PopScope only ever intercepts a pop of
// ITS OWN route, so screens pushed on top of the wrapped root (checkout,
// login, ...) still pop normally on the first back press — this only ever
// fires when the user is already at the root with nothing above it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_spacing.dart';

class DoubleBackToExit extends StatefulWidget {
  final Widget child;
  const DoubleBackToExit({super.key, required this.child});

  @override
  State<DoubleBackToExit> createState() => _DoubleBackToExitState();
}

class _DoubleBackToExitState extends State<DoubleBackToExit> {
  DateTime? _lastBackPress;
  bool _showToast = false;

  void _onBack() {
    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    setState(() => _showToast = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showToast = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onBack();
      },
      child: Stack(
        children: [
          widget.child,
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.xxl,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  duration: AppMotion.fast,
                  opacity: _showToast ? 1 : 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.inverseSurface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Press back again to exit',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onInverseSurface),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
