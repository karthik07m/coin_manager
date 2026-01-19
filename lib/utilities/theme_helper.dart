import 'package:flutter/material.dart';
import 'constants.dart';

/// Extension to provide theme-aware colors that adapt to light/dark mode
extension ThemeColors on BuildContext {
  /// Returns true if current theme is dark
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Primary text color - adapts to theme
  Color get textPrimary => isDark
      ? AppColors.textPrimary // White in dark
      : const Color(0xFF1F2937); // Softer, warmer dark in light

  /// Secondary text color - adapts to theme
  Color get textSecondary => isDark
      ? AppColors.textSecondary // Gray in dark
      : const Color(0xFF6B7280); // Warmer gray in light

  /// Background color - adapts to theme
  Color get appBackground => isDark
      ? AppColors.background // Almost black
      : const Color(0xFFF6F7F9); // Softer, warmer gray

  /// Surface color (for cards) - adapts to theme
  Color get appSurface => isDark
      ? AppColors.surface // Dark steel
      : const Color(0xFFFEFEFE); // Off-white instead of pure white

  /// Surface light color - adapts to theme
  Color get appSurfaceLight => isDark
      ? AppColors.surfaceLight // Lighter dark
      : const Color(0xFFFAFBFC); // Warmer very light gray

  /// Border color - adapts to theme
  Color get appBorder => isDark
      ? AppColors.border // Dark border
      : const Color(0xFFE5E7EB); // Subtle light border

  /// Divider color - adapts to theme
  Color get appDivider => isDark
      ? AppColors.divider // Dark divider
      : const Color(0xFFE5E7EB); // Subtle light divider
}
