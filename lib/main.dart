import 'package:coin_manager/utilities/constants.dart';
import 'package:coin_manager/utilities/responsive.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';

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
import 'screens/menu_scrn.dart';
import 'screens/transaction_form.dart';
import 'screens/privacy_policy.dart';
import 'screens/onboarding_screen.dart';
import 'screens/manage_budget.dart';
import 'screens/backup_management_screen.dart';
import 'screens/cloud_backup_screen.dart';
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
import 'screens/activity_history_screen.dart';
import 'screens/recurring_manager_screen.dart';
import 'utilities/page_transitions.dart';
import 'widgets/app_lock_gate.dart';

import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inter ships under SIL OFL 1.1, which requires its licence to travel with
  // the font. Loaded lazily — only read if a licence page is ever opened.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['Inter'],
      await rootBundle.loadString('assets/fonts/Inter-OFL.txt'),
    );
  });
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
            transactionProvider.baseAmountResolver =
                accountProvider.toBaseForAccount;
            transactionProvider.accountCurrencyResolver =
                accountProvider.currencyOfAccount;
            accountProvider.onRatesChanged = transactionProvider.reapplyRates;
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
          return DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) => _buildApp(
              context,
              settings,
              lightDynamic: lightDynamic,
              darkDynamic: darkDynamic,
            ),
          );
        },
      ),
    );
  }

  /// Builds the app's themes. When the user opts into Material You and the
  /// platform supplies a wallpaper palette (Android 12+), the whole app
  /// follows it — `context.appAccent` reads `colorScheme.primary`, so every
  /// screen picks it up without touching individual widgets.
  Widget _buildApp(
    BuildContext context,
    SettingsProvider settings, {
    ColorScheme? lightDynamic,
    ColorScheme? darkDynamic,
  }) {
    final bool dynamicAvailable =
        settings.useDynamicColor && lightDynamic != null;
    // Each brightness keeps its own accent: forcing the light palette's
    // primary onto the dark scheme washes the dark theme out.
    final Color lightAccent =
        dynamicAvailable ? lightDynamic.primary : settings.accentColor;
    final Color darkAccent = dynamicAvailable && darkDynamic != null
        ? darkDynamic.primary
        : settings.accentColor;
    Color onAccentFor(Color color) =>
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black;
    final accentColor = lightAccent;
    final lightColorScheme = (dynamicAvailable
            ? lightDynamic.harmonized()
            : ColorScheme.fromSeed(
                seedColor: accentColor,
                brightness: Brightness.light,
                surface: const Color(0xFFFEFEFE),
              ))
        .copyWith(
      primary: lightAccent,
      secondary: const Color(0xFF2196F3),
      onPrimary: onAccentFor(lightAccent),
      onSecondary: Colors.white,
      onSurface: const Color(0xFF1F2937),
    );
    final darkColorScheme = (dynamicAvailable && darkDynamic != null
            ? darkDynamic.harmonized()
            : ColorScheme.fromSeed(
                seedColor: accentColor,
                brightness: Brightness.dark,
                surface: AppColors.surface,
              ))
        .copyWith(
      primary: darkAccent,
      secondary: AppColors.secondary,
      onPrimary: onAccentFor(darkAccent),
      onSecondary: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,
    );

    // Cashew-style tonal palette for light mode - no pure whites. The page is
    // the accent washed toward white; cards are the scheme's secondary
    // container, so every shade stays in the accent's family.
    final lightBackground =
        Color.alphaBlend(lightAccent.withValues(alpha: 0.09), Colors.white);
    final lightSurface = Color.alphaBlend(Colors.white.withValues(alpha: 0.3),
        lightColorScheme.secondaryContainer);
    // Dark mode is a neutral graphite ladder instead: tinting every surface
    // turned the cards grey-olive next to the green balance card, which is now
    // the one green surface (balance_card.dart).
    const darkBackground = Color(0xFF0C0D0D);
    const darkSurface = Color(0xFF17191A);

    // Income/expense colours follow the theme actually on screen: the chosen
    // one, or the phone's own brightness when set to match the phone.
    AppColors.darkMode = switch (settings.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

    return MaterialApp(
      title: 'Coinly',
      themeMode: settings.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Inter',
        colorScheme: lightColorScheme.copyWith(surface: lightSurface),
        scaffoldBackgroundColor: lightBackground,
        cardTheme: CardThemeData(
          color: lightSurface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(AppDimensions.radiusMedium)),
          ),
        ),
        appBarTheme: AppBarTheme(
          // Modern finance-app header: flat (blends into the body),
          // left-aligned large bold title, roomier toolbar.
          backgroundColor: lightBackground,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 20,
          toolbarHeight: 64,
          titleTextStyle: AppTextStyles.h3.copyWith(
            color: const Color(0xFF1F2937), // Softer dark
            fontWeight: FontWeight.w700,
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
              color: lightSurface,
              borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: AppTextStyles.button,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(64, AppDimensions.buttonHeight),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: AppTextStyles.button,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
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
        // Cashew's sparkle ripple, with a fixed seed so it doesn't shimmer.
        splashFactory: kIsWeb
            ? InkRipple.splashFactory
            : InkSparkle.constantTurbulenceSeedSplashFactory,
        // Cashew-style fade-up on Android; iOS keeps its native swipe-back.
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Inter',
        colorScheme: darkColorScheme.copyWith(
          surface: darkSurface,
          // Sheets, dialogs and menus read these; keep them on the same ladder.
          surfaceContainerLowest: darkBackground,
          surfaceContainerLow: const Color(0xFF131516),
          surfaceContainer: darkSurface,
          surfaceContainerHigh: const Color(0xFF1E2122),
          surfaceContainerHighest: const Color(0xFF25282A),
        ),
        scaffoldBackgroundColor: darkBackground,
        cardTheme: CardThemeData(
          color: darkSurface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(AppDimensions.radiusMedium)),
          ),
        ),
        appBarTheme: AppBarTheme(
          // Modern finance-app header: flat (blends into the body),
          // left-aligned large bold title, roomier toolbar.
          backgroundColor: darkBackground,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 20,
          toolbarHeight: 64,
          titleTextStyle: AppTextStyles.h3.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
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
              color: darkSurface,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: AppTextStyles.button,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(64, AppDimensions.buttonHeight),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: AppTextStyles.button,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
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
        // Cashew's sparkle ripple, with a fixed seed so it doesn't shimmer.
        splashFactory: kIsWeb
            ? InkRipple.splashFactory
            : InkSparkle.constantTurbulenceSeedSplashFactory,
        // Cashew-style fade-up on Android; iOS keeps its native swipe-back.
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      // Update prompting differs by platform, and only one may run or the
      // user gets asked twice:
      //   Android - Play in-app updates download in the background and offer
      //             a restart (AppUpdateService, driven from MenuScrn).
      //   iOS     - no equivalent API, so fall back to a store prompt.
      // Either way a first-run user is never interrupted mid-onboarding.
      home: settings.isFirstLaunch
          ? const OnboardingScreen()
          : (!kIsWeb && Platform.isIOS)
              ? UpgradeAlert(
                  upgrader: Upgrader(
                    // Don't nag: re-prompt at most every few days after
                    // the user taps "Later".
                    durationUntilAlertAgain: const Duration(days: 3),
                    debugLogging: kDebugMode,
                  ),
                  child: const MenuScrn(),
                )
              : const MenuScrn(),
      debugShowCheckedModeBanner: false,
      // Clamp the OS text-scale factor app-wide so large accessibility
      // font settings still enlarge text without overflowing fixed-height
      // rows, cards and chips.
      builder: (context, child) => ClampedTextScale(
        child: AppLockGate(child: child ?? const SizedBox.shrink()),
      ),
      // Only routes that need arguments live here; the table below covers
      // the rest (Flutter checks `routes` first, so a name must not be in
      // both or its arguments are silently dropped).
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/manageBudget':
            final manageBudgetArgs = settings.arguments is ManageBudgetArgs
                ? settings.arguments as ManageBudgetArgs
                : null;
            final selectedMonth = manageBudgetArgs?.initialMonth ??
                (settings.arguments is DateTime
                    ? settings.arguments as DateTime
                    : null);
            return PageTransitions.fadeUp(
                ManageBudgetScreen(
                  initialMonth: selectedMonth,
                  autoAllocateOnOpen: manageBudgetArgs?.autoAllocate ?? false,
                ),
                settings: settings);
          default:
            return null; // Fall through to routes table
        }
      },
      routes: {
        TransactionForm.routeName: (ctx) => const TransactionForm(),
        AiAssistantScreen.routeName: (ctx) => const AiAssistantScreen(),
        CategoryManagementScreen.routeName: (ctx) =>
            const CategoryManagementScreen(),
        PrivacyPolicyScreen.routeName: (ctx) => const PrivacyPolicyScreen(),
        OnboardingScreen.routeName: (ctx) => const OnboardingScreen(),
        BackupManagementScreen.routeName: (ctx) =>
            const BackupManagementScreen(),
        CloudBackupScreen.routeName: (ctx) => const CloudBackupScreen(),
        DebtListScreen.routeName: (ctx) => const DebtListScreen(),
        DebtFormScreen.routeName: (ctx) => const DebtFormScreen(),
        DebtDetailScreen.routeName: (ctx) => const DebtDetailScreen(debtId: ''),
        GoalListScreen.routeName: (ctx) => const GoalListScreen(),
        GoalFormScreen.routeName: (ctx) => const GoalFormScreen(),
        GoalDetailScreen.routeName: (ctx) => const GoalDetailScreen(goalId: ''),
        AllTransactionsScreen.routeName: (ctx) => const AllTransactionsScreen(),
        AccountManagementScreen.routeName: (ctx) =>
            const AccountManagementScreen(),
        AccountFormScreen.routeName: (ctx) => const AccountFormScreen(),
        UpcomingPaymentsScreen.routeName: (ctx) =>
            const UpcomingPaymentsScreen(),
        ActivityHistoryScreen.routeName: (ctx) => const ActivityHistoryScreen(),
        RecurringManagerScreen.routeName: (ctx) =>
            const RecurringManagerScreen(),
      },
    );
  }
}
