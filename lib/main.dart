import 'package:coin_manager/utilities/constants.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/monthly_budget_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/account_provider.dart';
import 'providers/ai_assistant_provider.dart';

import 'screens/ai_assistant_screen.dart';
import 'screens/category_manger.dart';
import 'screens/create_category.dart';
import 'screens/menu_scrn.dart';
import 'screens/transaction_form.dart';
import 'screens/privacy_policy.dart';
import 'screens/activity_history_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/manage_budget.dart';
import 'screens/backup_management_screen.dart';
import 'screens/debt_list_screen.dart';
import 'screens/debt_form_screen.dart';
import 'screens/debt_detail_screen.dart';
import 'screens/goal_list_screen.dart';
import 'screens/goal_form_screen.dart';
import 'screens/goal_detail_screen.dart';
import 'screens/all_transactions_screen.dart';
import 'screens/account_management_screen.dart';
import 'screens/account_form_screen.dart';
import 'screens/upcoming_payments_screen.dart';
import 'utilities/page_transitions.dart';
import 'widgets/app_lock_gate.dart';

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
          create: (context) => AccountProvider(),
        ),
        // TransactionProvider depends on AccountProvider so a transaction
        // add/edit/delete/transfer can refresh account balances live. The
        // proxy only re-wires the callback; it never recreates the provider.
        ChangeNotifierProxyProvider<AccountProvider, TransactionProvider>(
          create: (context) => TransactionProvider(),
          update: (context, accountProvider, transactionProvider) {
            transactionProvider!.onBalancesAffected =
                accountProvider.refreshBalances;
            return transactionProvider;
          },
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
          create: (context) => GoalProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => AiAssistantProvider(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          final accentColor = settings.accentColor;
          final onAccentColor =
              ThemeData.estimateBrightnessForColor(accentColor) ==
                      Brightness.dark
                  ? Colors.white
                  : Colors.black;
          final lightColorScheme = ColorScheme.fromSeed(
            seedColor: accentColor,
            brightness: Brightness.light,
            surface: const Color(0xFFFEFEFE),
          ).copyWith(
            primary: accentColor,
            secondary: const Color(0xFF2196F3),
            onPrimary: onAccentColor,
            onSecondary: Colors.white,
            onSurface: const Color(0xFF1F2937),
          );
          final darkColorScheme = ColorScheme.fromSeed(
            seedColor: accentColor,
            brightness: Brightness.dark,
            surface: AppColors.surface,
          ).copyWith(
            primary: accentColor,
            secondary: AppColors.secondary,
            onPrimary: onAccentColor,
            onSecondary: AppColors.textPrimary,
            onSurface: AppColors.textPrimary,
          );

          return MaterialApp(
            title: 'Coinly',
            themeMode: settings.themeMode,
            theme: ThemeData(
              brightness: Brightness.light,
              colorScheme: lightColorScheme,
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
                // Modern finance-app header: flat (blends into the body),
                // left-aligned large bold title, roomier toolbar.
                backgroundColor: const Color(0xFFF6F7F9),
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                elevation: 0,
                centerTitle: false,
                titleSpacing: 20,
                toolbarHeight: 64,
                titleTextStyle: AppTextStyles.h3.copyWith(
                  color: const Color(0xFF1F2937), // Softer dark
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.3,
                ),
                iconTheme: const IconThemeData(
                  color: Color(0xFF1F2937), // Softer dark
                  size: AppDimensions.iconMedium,
                ),
              ),
              // Chip-styled back button used by every AppBar automatically.
              actionIconTheme: ActionIconThemeData(
                backButtonIconBuilder: (context) => Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFEFE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, size: 16),
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
                labelLarge: AppTextStyles.button,
                labelMedium: AppTextStyles.bodySmall,
                labelSmall: AppTextStyles.caption,
              ).apply(
                bodyColor: const Color(0xFF1F2937), // Softer dark
                displayColor: const Color(0xFF1F2937), // Softer dark
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(64, AppDimensions.buttonHeight),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  textStyle: AppTextStyles.button,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, AppDimensions.buttonHeight),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  textStyle: AppTextStyles.button,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: AppTextStyles.button,
                ),
              ),
              iconButtonTheme: IconButtonThemeData(
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(44),
                  iconSize: AppDimensions.iconMedium,
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: const Color(0xFF6B7280),
                ),
                labelStyle: AppTextStyles.bodyMedium.copyWith(
                  color: const Color(0xFF6B7280),
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                ),
              ),
              listTileTheme: ListTileThemeData(
                titleTextStyle: AppTextStyles.bodyLarge.copyWith(
                  color: const Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                ),
                subtitleTextStyle: AppTextStyles.bodySmall.copyWith(
                  color: const Color(0xFF6B7280),
                ),
                minVerticalPadding: 12,
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
              colorScheme: darkColorScheme,
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
                // Modern finance-app header: flat (blends into the body),
                // left-aligned large bold title, roomier toolbar.
                backgroundColor: AppColors.background,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                elevation: 0,
                centerTitle: false,
                titleSpacing: 20,
                toolbarHeight: 64,
                titleTextStyle: AppTextStyles.h3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.3,
                ),
                iconTheme: IconThemeData(
                  color: AppColors.textPrimary,
                  size: AppDimensions.iconMedium,
                ),
              ),
              // Chip-styled back button used by every AppBar automatically.
              actionIconTheme: ActionIconThemeData(
                backButtonIconBuilder: (context) => Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.divider.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
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
                labelLarge: AppTextStyles.button,
                labelMedium: AppTextStyles.bodySmall,
                labelSmall: AppTextStyles.caption,
              ).apply(
                bodyColor: AppColors.textPrimary,
                displayColor: AppColors.textPrimary,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(64, AppDimensions.buttonHeight),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  textStyle: AppTextStyles.button,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, AppDimensions.buttonHeight),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  textStyle: AppTextStyles.button,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: AppTextStyles.button,
                ),
              ),
              iconButtonTheme: IconButtonThemeData(
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(44),
                  iconSize: AppDimensions.iconMedium,
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                labelStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                ),
              ),
              listTileTheme: ListTileThemeData(
                titleTextStyle: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                subtitleTextStyle: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                minVerticalPadding: 12,
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
            builder: (context, child) =>
                AppLockGate(child: child ?? const SizedBox.shrink()),
            // onGenerateRoute provides context-aware transitions:
            // form screens slide up from bottom, detail screens scale+fade,
            // all others slide from right. Falls back to named routes table.
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case TransactionForm.routeName:
                  return PageTransitions.slideFromBottom(
                      const TransactionForm(),
                      settings: settings);
                case AiAssistantScreen.routeName:
                  return PageTransitions.slideFromBottom(
                      const AiAssistantScreen(),
                      settings: settings);
                case CreateCategoryScreen.routeName:
                  return PageTransitions.slideFromBottom(
                      const CreateCategoryScreen(),
                      settings: settings);
                case CategoryManagementScreen.routeName:
                  return PageTransitions.slideFromRight(
                      const CategoryManagementScreen(),
                      settings: settings);
                case PrivacyPolicyScreen.routeName:
                  return PageTransitions.slideFromRight(
                      const PrivacyPolicyScreen(),
                      settings: settings);
                case ActivityHistoryScreen.routeName:
                  return PageTransitions.slideFromRight(
                      const ActivityHistoryScreen(),
                      settings: settings);
                case OnboardingScreen.routeName:
                  return PageTransitions.fade(const OnboardingScreen(),
                      settings: settings);
                case '/manageBudget':
                  final manageBudgetArgs =
                      settings.arguments is ManageBudgetArgs
                          ? settings.arguments as ManageBudgetArgs
                          : null;
                  final selectedMonth = manageBudgetArgs?.initialMonth ??
                      (settings.arguments is DateTime
                          ? settings.arguments as DateTime
                          : null);
                  return PageTransitions.slideFromRight(
                      ManageBudgetScreen(
                        initialMonth: selectedMonth,
                        autoAllocateOnOpen:
                            manageBudgetArgs?.autoAllocate ?? false,
                      ),
                      settings: settings);
                case BackupManagementScreen.routeName:
                  return PageTransitions.slideFromRight(
                      const BackupManagementScreen(),
                      settings: settings);
                case DebtListScreen.routeName:
                  return PageTransitions.slideFromRight(const DebtListScreen(),
                      settings: settings);
                case DebtFormScreen.routeName:
                  return PageTransitions.slideFromBottom(const DebtFormScreen(),
                      settings: settings);
                case DebtDetailScreen.routeName:
                  return PageTransitions.scaleWithFade(
                      const DebtDetailScreen(debtId: ''),
                      settings: settings);
                case GoalListScreen.routeName:
                  return PageTransitions.slideFromRight(const GoalListScreen(),
                      settings: settings);
                case GoalFormScreen.routeName:
                  return PageTransitions.slideFromBottom(const GoalFormScreen(),
                      settings: settings);
                case GoalDetailScreen.routeName:
                  return PageTransitions.scaleWithFade(
                      const GoalDetailScreen(goalId: ''),
                      settings: settings);
                case AllTransactionsScreen.routeName:
                  return PageTransitions.slideFromRight(
                      const AllTransactionsScreen(),
                      settings: settings);
                case AccountManagementScreen.routeName:
                  return PageTransitions.slideFromRight(
                      const AccountManagementScreen(),
                      settings: settings);
                case AccountFormScreen.routeName:
                  return PageTransitions.slideFromBottom(
                      const AccountFormScreen(),
                      settings: settings);
                case UpcomingPaymentsScreen.routeName:
                  return PageTransitions.slideFromRight(
                      const UpcomingPaymentsScreen(),
                      settings: settings);
                default:
                  return null; // Fall through to routes table
              }
            },
            routes: {
              TransactionForm.routeName: (ctx) => const TransactionForm(),
              AiAssistantScreen.routeName: (ctx) => const AiAssistantScreen(),
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
              GoalListScreen.routeName: (ctx) => const GoalListScreen(),
              GoalFormScreen.routeName: (ctx) => const GoalFormScreen(),
              GoalDetailScreen.routeName: (ctx) =>
                  const GoalDetailScreen(goalId: ''),
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
