import 'package:flutter/material.dart';

String appName = "Coin Manager";

int defaultExpenseCat = 1;
int defaultIncomeCat = 9;

// Color Constants
class AppColors {
  // Base Colors - Deeper, richer dark theme
  static const Color background =
      Color(0xFF0F1115); // Almost black, slightly cool
  static const Color surface = Color(0xFF181B21); // Dark steel
  static const Color surfaceLight =
      Color(0xFF232830); // Lighter surface for cards

  // Accent Colors - Vibrant and Neon-ish
  static const Color primary = Color(0xFF2ECC71); // Vibrant Emerald
  static const Color secondary = Color(0xFFFFD700); // Electric Gold
  static const Color accentPurple = Color(0xFF9B59B6); // Amethyst
  static const Color accentBlue = Color(0xFF3498DB); // Bright Blue

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF); // Pure White
  static const Color textSecondary = Color(0xFFA1A1AA); // Cool Gray
  static const Color textTertiary = Color(0xFF52525B); // Darker Gray

  // Status Colors
  static const Color positive = Color(0xFF2ECC71); // Green
  static const Color negative = Color(0xFFFF5252); // Bright Red
  static const Color warning = Color(0xFFFFA726); // Orange

  // UI Elements
  static const Color divider = Color(0xFF27272A);
  static const Color border = Color(0xFF27272A);
}

// Dropshadows for depth
class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get floating => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];
}

// Typography
class AppTextStyles {
  // Headings
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -1.0,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.3,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    height: 1.4,
  );

  // Body Text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.2,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );

  // Special Text
  static const TextStyle amount = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    fontFamily: 'Monospace', // Or system monospace if font not available
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    height: 1.3,
  );
}

// Dimensions
class AppDimensions {
  // Spacing
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusExtraLarge = 32.0;

  // Elevation
  static const double elevationSmall = 2.0;
  static const double elevationMedium = 8.0;
  static const double elevationLarge = 16.0;

  // Icon Sizes
  static const double iconSmall = 18.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;

  // Component Sizes
  static const double avatarSize = 48.0;
  static const double buttonHeight =
      48.0; // Reduced from 56 for better proportions
  static const double inputHeight = 60.0;
}

// Animation Durations
class AppDurations {
  static const Duration fastest = Duration(milliseconds: 150);
  static const Duration fast = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 700);
  static const Duration slowest = Duration(milliseconds: 1000);
}

// Sample icons list for category selection
final List<String> categoryIcons = [
  'assets/categories/food.png',
  'assets/categories/groceries.png',
  'assets/categories/shopping.png',
  'assets/categories/transport.png',
  'assets/categories/entertainment.png',
  'assets/categories/salary.png',
  'assets/categories/bonus.png',
  'assets/categories/stocks.png',
  'assets/categories/travel.png',
  'assets/categories/bill.png',
  'assets/categories/other.png',
  'assets/categories/budget.png',
  'assets/categories/diet.png',
];

extension TextStyleExtensions on TextStyle {
  TextStyle get uppercase => copyWith(
        fontFeatures: [
          const FontFeature.enable('smcp')
        ], // Small caps if supported
      );
}
