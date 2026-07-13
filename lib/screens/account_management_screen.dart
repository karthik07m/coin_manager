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
        title: const Text('Manage Accounts'),
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
            itemCount: accounts.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildNetWorthHeader(
                    context, accountProvider, currencySymbol);
              }
              final account = accounts[index - 1];
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
        backgroundColor: context.appAccent,
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
    );
  }

  Widget _buildNetWorthHeader(
    BuildContext context,
    AccountProvider accountProvider,
    String currencySymbol,
  ) {
    final netWorth = accountProvider.netWorth;
    final assets = accountProvider.totalAssets;
    final liabilities = accountProvider.totalLiabilities;
    final netColor = netWorth >= 0 ? context.appAccent : AppColors.negative;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            netColor.withValues(alpha: 0.18),
            netColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: netColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NET WORTH',
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            UtilityFunction.formatMoney(netWorth, symbol: currencySymbol),
            style: AppTextStyles.h1.copyWith(
              color: netColor,
              fontWeight: FontWeight.w800,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _netWorthStat(
                  context,
                  label: 'Assets',
                  value: UtilityFunction.formatMoney(assets,
                      symbol: currencySymbol),
                  color: AppColors.positive,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: AppColors.divider.withValues(alpha: 0.4),
              ),
              Expanded(
                child: _netWorthStat(
                  context,
                  label: 'Liabilities',
                  value: UtilityFunction.formatMoney(liabilities,
                      symbol: currencySymbol),
                  color: AppColors.negative,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _netWorthStat(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    Account account,
    AccountProvider accountProvider,
    String currencySymbol,
  ) {
    final color = Color(Account.colorFromHex(account.color));
    final isLiability = account.isLiability;

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
                              color: context.appAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'DEFAULT',
                              style: AppTextStyles.caption.copyWith(
                                color: context.appAccent,
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
                      isLiability
                          ? '${account.type.label} · owed'
                          : account.type.label,
                      style: AppTextStyles.caption.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Balance (liabilities shown as amount owed, in red)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    UtilityFunction.formatMoney(account.currentBalance,
                        symbol: currencySymbol),
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isLiability
                          ? AppColors.negative
                          : (account.currentBalance < 0
                              ? AppColors.negative
                              : context.textPrimary),
                    ),
                  ),
                  Text(
                    isLiability ? 'balance owed' : 'available',
                    style: AppTextStyles.caption.copyWith(
                      color: context.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
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
