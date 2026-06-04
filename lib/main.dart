import 'package:coin_manager/utilities/constants.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/monthly_budget_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/account_provider.dart';

import 'screens/category_manger.dart';
import 'screens/create_category.dart';
import 'screens/menu_scrn.dart';
import 'screens/transaction_form.dart';
import 'screens/privacy_policy.dart';
import 'screens/onboarding_screen.dart';
import 'screens/manage_budget.dart';
import 'screens/backup_management_screen.dart';
import 'screens/debt_list_screen.dart';
import 'screens/debt_form_screen.dart';
import 'screens/debt_detail_screen.dart';
import 'screens/all_transactions_screen.dart';
import 'screens/account_management_screen.dart';
import 'screens/account_form_screen.dart';
import 'screens/upcoming_payments_screen.dart';
import 'utilities/page_transitions.dart';

import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
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
        ChangeNotifierProvider(
          create: (context) => DebtProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => AccountProvider(),
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
                primary: const Color(0xFF4CAF50), // Softer green for light mode
                secondary: const Color(0xFF2196F3), // Blue instead of gold
                surface: const Color(0xFFFEFEFE), // Off-white
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onSurface: const Color(0xFF1F2937), // Softer dark text
              ),
              scaffoldBackgroundColor:
                  const Color(0xFFF6F7F9), // Warmer, softer gray
              cardTheme: CardThemeData(
                color: const Color(0xFFFEFEFE), // Off-white
                elevation: AppDimensions.elevationMedium,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                      Radius.circular(AppDimensions.radiusMedium)),
                ),
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: const Color(0xFFFEFEFE), // Off-white
                elevation: 0.5, // Subtle elevation for depth
                centerTitle: true,
                titleTextStyle: AppTextStyles.h2.copyWith(
                  color: const Color(0xFF1F2937), // Softer dark
                ),
                iconTheme: const IconThemeData(
                  color: Color(0xFF1F2937), // Softer dark
                  size: AppDimensions.iconMedium,
                ),
              ),
              iconTheme: const IconThemeData(
                color: Color(0xFF1F2937), // Softer dark
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
                bodyColor: const Color(0xFF1F2937), // Softer dark
                displayColor: const Color(0xFF1F2937), // Softer dark
              ),
              useMaterial3: true,
              // Smooth slide transitions globally for push/pop routes
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                },
              ),
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
              // Smooth slide transitions globally for push/pop routes
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                },
              ),
            ),
            home: settings.isFirstLaunch
                ? const OnboardingScreen()
                : const MenuScrn(),
            debugShowCheckedModeBanner: false,
            // onGenerateRoute provides context-aware transitions:
            // form screens slide up from bottom, detail screens scale+fade,
            // all others slide from right. Falls back to named routes table.
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case TransactionForm.routeName:
                  return PageTransitions.slideFromBottom(
                      const TransactionForm(), settings: settings);
                case CreateCategoryScreen.routeName:
                  return PageTransitions.slideFromBottom(
                      const CreateCategoryScreen(), settings: settings);
                case CategoryManagementScreen.routeName:
                  return PageTransitions.slideFromRight(
                      const CategoryManagementScreen(), settings: settings);
                case PrivacyPolicyScreen.routeName:
                  return PageTransitions.slideFromRight(
                      const PrivacyPolicyScreen(), settings: settings);
                case OnboardingScreen.routeName:
                  return PageTransitions.fade(
                      const OnboardingScreen(), settings: settings);
                case '/manageBudget':
                  return PageTransitions.slideFromRight(
                      const ManageBudgetScreen(), settings: settings);
                case BackupManagementScreen.routeName:
                  return PageTransitions.slideFromRight(
                      const BackupManagementScreen(), settings: settings);
                case DebtListScreen.routeName:
                  return PageTransitions.slideFromRight(
                      const DebtListScreen(), settings: settings);
                case DebtFormScreen.routeName:
                  return PageTransitions.slideFromBottom(
                      const DebtFormScreen(), settings: settings);
                case DebtDetailScreen.routeName:
                  return PageTransitions.scaleWithFade(
                      const DebtDetailScreen(debtId: ''), settings: settings);
                case AllTransactionsScreen.routeName:
                  return PageTransitions.slideFromRight(
                      const AllTransactionsScreen(), settings: settings);
                case AccountManagementScreen.routeName:
                  return PageTransitions.slideFromRight(
                      const AccountManagementScreen(), settings: settings);
                case AccountFormScreen.routeName:
                  return PageTransitions.slideFromBottom(
                      const AccountFormScreen(), settings: settings);
                case UpcomingPaymentsScreen.routeName:
                  return PageTransitions.slideFromRight(
                      const UpcomingPaymentsScreen(), settings: settings);
                default:
                  return null; // Fall through to routes table
              }
            },
            routes: {
              TransactionForm.routeName: (ctx) => const TransactionForm(),
              CreateCategoryScreen.routeName: (ctx) =>
                  const CreateCategoryScreen(),
              CategoryManagementScreen.routeName: (ctx) =>
                  const CategoryManagementScreen(),
              PrivacyPolicyScreen.routeName: (ctx) =>
                  const PrivacyPolicyScreen(),
              OnboardingScreen.routeName: (ctx) => const OnboardingScreen(),
              '/manageBudget': (ctx) => const ManageBudgetScreen(),
              BackupManagementScreen.routeName: (ctx) =>
                  const BackupManagementScreen(),
              DebtListScreen.routeName: (ctx) => const DebtListScreen(),
              DebtFormScreen.routeName: (ctx) => const DebtFormScreen(),
              DebtDetailScreen.routeName: (ctx) =>
                  const DebtDetailScreen(debtId: ''),
              AllTransactionsScreen.routeName: (ctx) =>
                  const AllTransactionsScreen(),
              AccountManagementScreen.routeName: (ctx) =>
                  const AccountManagementScreen(),
              AccountFormScreen.routeName: (ctx) => const AccountFormScreen(),
              UpcomingPaymentsScreen.routeName: (ctx) =>
                  const UpcomingPaymentsScreen(),
            },
          );
        },
      ),
    );
  }
}
