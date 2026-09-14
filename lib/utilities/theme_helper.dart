import 'package:flutter/material.dart';
import 'constants.dart';

/// Extension to provide theme-aware colors that adapt to light/dark mode
extension ThemeColors on BuildContext {
  /// Returns true if current theme is dark
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Current user-selected accent color.
  Color get appAccent => Theme.of(this).colorScheme.primary;

  /// Primary text color - adapts to theme
  Color get textPrimary => isDark
      ? AppColors.textPrimary // White in dark
      : const Color(0xFF1F2937); // Softer, warmer dark in light

  /// Secondary text color - adapts to theme
  Color get textSecondary => isDark
      ? AppColors.textSecondary // Gray in dark
      : const Color(0xFF6B7280); // Warmer gray in light

  /// Page background: the accent washed toward white/black (main.dart).
  Color get appBackground => Theme.of(this).scaffoldBackgroundColor;

  /// Card fill: a tonal shade of the accent, never plain white (main.dart).
  Color get appSurface => Theme.of(this).colorScheme.surface;

  /// Secondary panels: a step off the card surface.
  Color get appSurfaceLight => isDark
      ? Color.alphaBlend(Colors.white.withValues(alpha: 0.05), appSurface)
      : Color.lerp(appBackground, appSurface, 0.5)!;

  /// Opaque tonal fill: a small accent tint without a compositing layer.
  Color get appAccentSurface => Color.alphaBlend(
        appAccent.withValues(alpha: isDark ? 0.13 : 0.09),
        appSurface,
      );

  /// Border color: the scheme's tinted outline, softened onto the card.
  Color get appBorder => Color.alphaBlend(
        Theme.of(this).colorScheme.outlineVariant.withValues(alpha: 0.5),
        appSurface,
      );

  /// Cards separate from the page by tone, not outline, in both themes.
  BoxBorder? get cardBorder => null;

  /// Divider color - adapts to theme
  Color get appDivider => appBorder;
}
