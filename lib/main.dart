import 'package:coin_manager/utilities/constants.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/monthly_budget_provider.dart';
import 'providers/settings_provider.dart';

import 'screens/category_manger.dart';
import 'screens/create_category.dart';
import 'screens/menu_scrn.dart';
import 'screens/transaction_form.dart';
import 'screens/privacy_policy.dart';
import 'screens/onboarding_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => TransactionProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => CategoryProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => MonthlyBudgetProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => SettingsProvider(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'Coin Manager',
            themeMode: settings.themeMode,
            theme: ThemeData(
              brightness: Brightness.light,
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
                secondary: AppColors.secondary,
                surface: Colors.white,
                onPrimary: Colors.white,
                onSecondary: Colors.black,
                onSurface: Colors.black,
              ),
              scaffoldBackgroundColor: Colors.grey[50],
              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: AppDimensions.elevationMedium,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                      Radius.circular(AppDimensions.radiusMedium)),
                ),
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                titleTextStyle: AppTextStyles.h2.copyWith(color: Colors.black),
                iconTheme: IconThemeData(
                  color: Colors.black,
                  size: AppDimensions.iconMedium,
                ),
              ),
              iconTheme: IconThemeData(
                color: Colors.black,
                size: AppDimensions.iconMedium,
              ),
              textTheme: TextTheme(
                displayLarge: AppTextStyles.h1,
                displayMedium: AppTextStyles.h2,
                displaySmall: AppTextStyles.h3,
                bodyLarge: AppTextStyles.bodyLarge,
                bodyMedium: AppTextStyles.bodyMedium,
                bodySmall: AppTextStyles.bodySmall,
                labelLarge: AppTextStyles.amount,
                labelSmall: AppTextStyles.caption,
              ).apply(
                bodyColor: Colors.black,
                displayColor: Colors.black,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.dark(
                primary: AppColors.primary,
                secondary: AppColors.secondary,
                surface: AppColors.surface,
                onPrimary: AppColors.textPrimary,
                onSecondary: AppColors.textPrimary,
                onSurface: AppColors.textPrimary,
              ),
              scaffoldBackgroundColor: AppColors.background,
              cardTheme: CardThemeData(
                color: AppColors.surface,
                elevation: AppDimensions.elevationMedium,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                      Radius.circular(AppDimensions.radiusMedium)),
                ),
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: AppColors.surface,
                elevation: 0,
                centerTitle: true,
                titleTextStyle:
                    AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
                iconTheme: IconThemeData(
                  color: AppColors.textPrimary,
                  size: AppDimensions.iconMedium,
                ),
              ),
              iconTheme: IconThemeData(
                color: AppColors.textPrimary,
                size: AppDimensions.iconMedium,
              ),
              textTheme: TextTheme(
                displayLarge: AppTextStyles.h1,
                displayMedium: AppTextStyles.h2,
                displaySmall: AppTextStyles.h3,
                bodyLarge: AppTextStyles.bodyLarge,
                bodyMedium: AppTextStyles.bodyMedium,
                bodySmall: AppTextStyles.bodySmall,
                labelLarge: AppTextStyles.amount,
                labelSmall: AppTextStyles.caption,
              ).apply(
                bodyColor: AppColors.textPrimary,
                displayColor: AppColors.textPrimary,
              ),
              useMaterial3: true,
            ),
            home: settings.isFirstLaunch
                ? const OnboardingScreen()
                : const MenuScrn(),
            debugShowCheckedModeBanner: false,
            routes: {
              TransactionForm.routeName: (ctx) => const TransactionForm(),
              CreateCategoryScreen.routeName: (ctx) =>
                  const CreateCategoryScreen(),
              CategoryManagementScreen.routeName: (ctx) =>
                  const CategoryManagementScreen(),
              PrivacyPolicyScreen.routeName: (ctx) =>
                  const PrivacyPolicyScreen(),
              OnboardingScreen.routeName: (ctx) => const OnboardingScreen(),
            },
          );
        },
      ),
    );
  }
}
