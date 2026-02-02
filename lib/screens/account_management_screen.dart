import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../models/account.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';
import '../providers/settings_provider.dart';
import 'account_form_screen.dart';

class AccountManagementScreen extends StatefulWidget {
  static const routeName = '/account-management';

  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Load accounts when screen opens
    Future.microtask(() {
      if (!mounted) return;
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);
      if (!accountProvider.isLoaded) {
        accountProvider.loadAccounts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        title: const Text('Manage Accounts', style: AppTextStyles.h2),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer2<AccountProvider, SettingsProvider>(
        builder: (context, accountProvider, settingsProvider, child) {
          final currencySymbol = settingsProvider.currencySymbol;
          if (!accountProvider.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final accounts = accountProvider.accounts;

          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 80,
                    color: context.textSecondary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No accounts yet',
                    style: AppTextStyles.h3.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return _buildAccountCard(
                  context, account, accountProvider, currencySymbol);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AccountFormScreen.routeName);
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    Account account,
    AccountProvider accountProvider,
    String currencySymbol,
  ) {
    final color = Color(Account.colorFromHex(account.color));

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AccountFormScreen.routeName,
            arguments: account.id,
          );
        },
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconData(account.icon),
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing16),

              // Name and balance
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          account.name,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (account.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'DEFAULT',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Balance: ${UtilityFunction.formatMoney(account.currentBalance, symbol: currencySymbol)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.chevron_right,
                color: context.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'account_balance':
        return Icons.account_balance;
      case 'credit_card':
        return Icons.credit_card;
      case 'payment':
        return Icons.payment;
      case 'savings':
        return Icons.savings;
      default:
        return Icons.account_balance_wallet;
    }
  }
}
