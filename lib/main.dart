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
        title: 'Flutter Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            primary: kPrimaryColor,
            secondary: ksecondTextColor,
            seedColor: Colors.grey,
            error: Colors.red,
            brightness: Brightness.dark,
            onTertiary: Colors.greenAccent,
          ),
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
