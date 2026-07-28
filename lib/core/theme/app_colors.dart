// lib/core/theme/app_colors.dart
//
// Raw palette values — the ONLY file in the app allowed to contain hex codes.
// Everything else reads colors through Theme.of(context) or AppSemantic
// (see app_theme.dart), so light/dark mode both stay correct automatically.
//
// Palette: fresh green + food amber, chosen for a grocery/produce store.

import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF059669); // emerald 600
  static const primaryDark = Color(0xFF34D399); // lifted for dark-mode contrast
  static const secondary = Color(0xFF10B981);
  static const accent = Color(0xFFD97706); // amber — CTA / price emphasis
  static const accentDark = Color(0xFFFBBF24);

  // Light surfaces
  static const background = Color(0xFFF7FBF9); // barely-green tinted canvas
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF0F8F6);
  static const border = Color(0xFFE1F2ED);

  // Light text — both pass 4.5:1 on the surfaces above
  static const foreground = Color(0xFF0F172A);
  static const foregroundMuted = Color(0xFF556070);

  // Dark surfaces
  static const backgroundDark = Color(0xFF0B1412);
  static const surfaceDark = Color(0xFF13201D);
  static const surfaceMutedDark = Color(0xFF1B2B27);
  static const borderDark = Color(0xFF2A3D38);

  // Dark text — primary ≥4.5:1, secondary ≥3:1 on the dark surfaces
  static const foregroundDark = Color(0xFFECFDF5);
  static const foregroundMutedDark = Color(0xFF9DB2AC);

  // "On" colors for dark mode. The dark-mode brand colors are light tints, so
  // text sitting on top of them has to be dark, not white — a very dark shade
  // of the same hue keeps the pairing above 4.5:1.
  static const onBrandDark = Color(0xFF04231A);
  static const onAccentDark = Color(0xFF2A1A02);
  static const onDestructiveDark = Color(0xFF2A0606);

  // Status — each is paired with an icon in the UI so colour is never the
  // sole signal (accessibility: color-not-only-indicator).
  static const success = Color(0xFF059669);
  static const successDark = Color(0xFF34D399);
  static const warning = Color(0xFFD97706);
  static const warningDark = Color(0xFFFBBF24);
  static const destructive = Color(0xFFDC2626);
  static const destructiveDark = Color(0xFFF87171);
  static const info = Color(0xFF0284C7);
  static const infoDark = Color(0xFF38BDF8);

  // Category tint for the two product types.
  static const grocery = Color(0xFF059669);
  static const fruitVeg = Color(0xFFEA580C);
  static const groceryDark = Color(0xFF34D399);
  static const fruitVegDark = Color(0xFFFB923C);
}
