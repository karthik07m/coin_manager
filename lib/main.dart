import 'package:coin_manager/utilities/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/monthly_budget_provider.dart'; // Import the MonthlyBudgetProvider

import 'screens/category_manger.dart';
import 'screens/create_category.dart';
import 'screens/menu_scrn.dart';
import 'screens/transaction_form.dart';

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
          create: (context) =>
              MonthlyBudgetProvider(), // Add MonthlyBudgetProvider
        ),
      ],
      child: MaterialApp(
        title: 'Coin Manager',
        theme: ThemeData(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            background: AppColors.background,
            surface: AppColors.surface,
            onPrimary: AppColors.textPrimary,
            onSecondary: AppColors.textPrimary,
            onBackground: AppColors.textPrimary,
            onSurface: AppColors.textPrimary,
          ),
          scaffoldBackgroundColor: AppColors.background,
          cardTheme: CardThemeData(
            color: AppColors.surface,
            elevation: AppDimensions.elevationMedium,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.surface,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: AppTextStyles.h2,
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
          ),
          useMaterial3: true,
        ),
        home: const MenuScrn(),
        debugShowCheckedModeBanner: false,
        routes: {
          TransactionForm.routeName: (ctx) => const TransactionForm(),
          CreateCategoryScreen.routeName: (ctx) => const CreateCategoryScreen(),
          CategoryManagementScreen.routeName: (ctx) =>
              const CategoryManagementScreen(),
          // Add other routes here as needed
        },
      ),
    );
  }
}
