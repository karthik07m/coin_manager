import 'package:flutter/material.dart';

String appName = "Coin Manager";

int defaultExpenseCat = 1;
int defaultIncomeCat = 9;

// Color Constants
class AppColors {
  // Base Colors
  static const Color background = Color(0xFF121212); // Charcoal
  static const Color surface = Color(0xFF1E1E1E); // Dark Gray
  static const Color divider = Color(0xFF424242); // Gray 700

  // Accent Colors
  static const Color primary = Color(0xFF43A047); // Deep Green
  static const Color secondary = Color(0xFFFFC107); // Amber

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFBDBDBD); // Gray 300

  // Status Colors
  static const Color positive = Color(0xFF4CAF50); // Green
  static const Color negative = Color(0xFFF44336); // Red

  // Overlay Colors
  static const Color overlay = Color(0x1A000000); // 10% Black
  static const Color cardShadow = Color(0x0D000000); // 5% Black
}

// Typography
class AppTextStyles {
  // Headings
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.25,
    height: 1.3,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0,
    height: 1.4,
  );

  // Body Text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    letterSpacing: 0.25,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    letterSpacing: 0.4,
    height: 1.3,
  );

  // Special Text
  static const TextStyle amount = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.15,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    letterSpacing: 0.4,
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
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  // Elevation
  static const double elevationSmall = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationLarge = 8.0;

  // Icon Sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;

  // Component Sizes
  static const double avatarSize = 40.0;
  static const double buttonHeight = 48.0;
  static const double inputHeight = 56.0;
}

// Animation Durations
class AppDurations {
  static const Duration fastest = Duration(milliseconds: 150);
  static const Duration fast = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 350);
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
