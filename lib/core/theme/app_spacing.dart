// lib/core/theme/app_spacing.dart
//
// 4/8dp spacing rhythm + shared radii and icon sizes. Use these instead of
// literal EdgeInsets numbers so component, section and page spacing stay on
// the same scale.

abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  /// Horizontal page gutter. Widens on tablets — see [gutterFor].
  static const gutter = 16.0;

  /// Adaptive gutter by width class (phone / large phone / tablet).
  static double gutterFor(double width) {
    if (width >= 900) return 32;
    if (width >= 600) return 24;
    return gutter;
  }

  /// Max text/content measure so paragraphs and forms don't run
  /// edge-to-edge on tablets.
  static const contentMaxWidth = 560.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const pill = 999.0;
}

/// Icon sizes as tokens — avoids the random 20/22/26 mixing that reads as
/// sloppy.
abstract final class AppIconSize {
  static const sm = 16.0;
  static const md = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const hero = 48.0;
}

/// Motion: micro-interactions stay in the 150-300ms band.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 300);
}

/// Minimum tap target (Android 48dp; also clears the iOS 44pt floor).
const double kMinTapTarget = 48.0;
