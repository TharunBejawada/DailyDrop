// lib/core/theme/app_theme.dart
//
// Light + dark ThemeData built from AppColors. Screens should never reach
// into AppColors directly: read Theme.of(context).colorScheme for brand and
// surface colors, and AppSemantic.of(context) for status colors (success /
// warning / danger / the two product-type tints), which need a per-mode
// value to stay legible in both themes.

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// Semantic colors that aren't part of Material's ColorScheme but still need
/// to flip between light and dark.
@immutable
class AppSemantic extends ThemeExtension<AppSemantic> {
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color grocery;
  final Color fruitVeg;
  final Color mutedText;
  final Color trackInactive;

  const AppSemantic({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.grocery,
    required this.fruitVeg,
    required this.mutedText,
    required this.trackInactive,
  });

  static const light = AppSemantic(
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.destructive,
    info: AppColors.info,
    grocery: AppColors.grocery,
    fruitVeg: AppColors.fruitVeg,
    mutedText: AppColors.foregroundMuted,
    trackInactive: AppColors.border,
  );

  static const dark = AppSemantic(
    success: AppColors.successDark,
    warning: AppColors.warningDark,
    danger: AppColors.destructiveDark,
    info: AppColors.infoDark,
    grocery: AppColors.groceryDark,
    fruitVeg: AppColors.fruitVegDark,
    mutedText: AppColors.foregroundMutedDark,
    trackInactive: AppColors.borderDark,
  );

  /// Never returns null — falls back to [light] if the extension is missing,
  /// so a widget used outside the app theme (e.g. in a test) still renders.
  static AppSemantic of(BuildContext context) =>
      Theme.of(context).extension<AppSemantic>() ?? light;

  @override
  AppSemantic copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? grocery,
    Color? fruitVeg,
    Color? mutedText,
    Color? trackInactive,
  }) {
    return AppSemantic(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      grocery: grocery ?? this.grocery,
      fruitVeg: fruitVeg ?? this.fruitVeg,
      mutedText: mutedText ?? this.mutedText,
      trackInactive: trackInactive ?? this.trackInactive,
    );
  }

  @override
  AppSemantic lerp(AppSemantic? other, double t) {
    if (other == null) return this;
    return AppSemantic(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      grocery: Color.lerp(grocery, other.grocery, t)!,
      fruitVeg: Color.lerp(fruitVeg, other.fruitVeg, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      trackInactive: Color.lerp(trackInactive, other.trackInactive, t)!,
    );
  }
}

abstract final class AppTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.surfaceMuted,
          onPrimaryContainer: AppColors.primary,
          secondary: AppColors.secondary,
          onSecondary: Colors.white,
          tertiary: AppColors.accent,
          onTertiary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.foreground,
          surfaceContainerLowest: AppColors.surface,
          surfaceContainerLow: AppColors.background,
          surfaceContainer: AppColors.surfaceMuted,
          surfaceContainerHighest: AppColors.surfaceMuted,
          onSurfaceVariant: AppColors.foregroundMuted,
          outline: AppColors.border,
          outlineVariant: AppColors.border,
          error: AppColors.destructive,
          onError: Colors.white,
        ),
        canvas: AppColors.background,
        semantic: AppSemantic.light,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme.dark(
          primary: AppColors.primaryDark,
          onPrimary: AppColors.onBrandDark,
          primaryContainer: AppColors.surfaceMutedDark,
          onPrimaryContainer: AppColors.primaryDark,
          secondary: AppColors.secondary,
          onSecondary: AppColors.onBrandDark,
          tertiary: AppColors.accentDark,
          onTertiary: AppColors.onAccentDark,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.foregroundDark,
          surfaceContainerLowest: AppColors.backgroundDark,
          surfaceContainerLow: AppColors.surfaceDark,
          surfaceContainer: AppColors.surfaceMutedDark,
          surfaceContainerHighest: AppColors.surfaceMutedDark,
          onSurfaceVariant: AppColors.foregroundMutedDark,
          outline: AppColors.borderDark,
          outlineVariant: AppColors.borderDark,
          error: AppColors.destructiveDark,
          onError: AppColors.onDestructiveDark,
        ),
        canvas: AppColors.backgroundDark,
        semantic: AppSemantic.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color canvas,
    required AppSemantic semantic,
  }) {
    // Rubik for headings (geometric, confident), Nunito Sans for body/UI
    // (open counters, reads well at small sizes on cheap phone screens).
    final base = brightness == Brightness.light
        ? ThemeData.light(useMaterial3: true)
        : ThemeData.dark(useMaterial3: true);

    final display = GoogleFonts.rubikTextTheme(base.textTheme);
    final body = GoogleFonts.nunitoSansTextTheme(base.textTheme);

    final textTheme = base.textTheme
        .copyWith(
          displayLarge: display.displayLarge,
          displayMedium: display.displayMedium,
          displaySmall: display.displaySmall,
          headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
          headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          headlineSmall: display.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          titleMedium: display.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall: display.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          // Body stays 16px base with 1.5 line-height for readability.
          bodyLarge: body.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
          bodyMedium: body.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
          bodySmall: body.bodySmall?.copyWith(fontSize: 12, height: 1.4),
          labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          labelMedium: body.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          labelSmall: body.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      textTheme: textTheme,
      extensions: [semantic],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,

      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 20),
        iconTheme: IconThemeData(color: scheme.onSurface, size: AppIconSize.lg),
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          // A visible 1px outline keeps cards separated from the canvas in
          // BOTH themes — elevation alone disappears in dark mode.
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: AppSpacing.xl,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, kMinTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, kMinTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, kMinTapTarget),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? AppColors.surfaceMuted
            : AppColors.surfaceMutedDark,
        // Labels stay visible above the field rather than collapsing into a
        // placeholder-only label.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: textTheme.bodyMedium?.copyWith(color: semantic.mutedText),
        helperStyle: textTheme.bodySmall?.copyWith(color: semantic.mutedText),
        helperMaxLines: 2,
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        errorMaxLines: 3,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: semantic.mutedText,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: scheme.outlineVariant,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 3),
          insets: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 3,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: AppIconSize.lg,
            color: selected ? scheme.primary : semantic.mutedText,
          );
        }),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.light
            ? AppColors.foreground
            : AppColors.surfaceMutedDark,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: AppColors.primaryDark,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        // 50% scrim so the dialog reads as clearly foreground.
        barrierColor: Colors.black54,
        titleTextStyle: textTheme.titleLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black54,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        titleTextStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: semantic.mutedText),
        iconColor: semantic.mutedText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: semantic.trackInactive,
        circularTrackColor: Colors.transparent,
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : semantic.mutedText,
        ),
      ),

      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(scheme.outline),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
