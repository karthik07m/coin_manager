import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../models/account.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';
import '../providers/settings_provider.dart';
import 'account_form_screen.dart';
import '../widgets/transfer_sheet.dart';

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
      final base = Provider.of<SettingsProvider>(context, listen: false)
          .currencyCode;
      if (!accountProvider.isLoaded) {
        accountProvider.loadAccounts();
      }
      // Load live FX rates so mixed-currency balances convert for net worth.
      accountProvider.loadRates(base);
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
        actions: [
          IconButton(
            tooltip: 'Transfer between accounts',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: () => showTransferSheet(context),
          ),
          const SizedBox(width: 4),
        ],
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

          // Leading cards above the account list: net worth, then an
          // optional combined credit-card usage summary.
          final showCreditUsage = accountProvider.hasCreditCardsWithLimit;
          final leadingCount = showCreditUsage ? 2 : 1;

          return ListView.builder(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            itemCount: accounts.length + leadingCount,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildNetWorthHeader(
                    context, accountProvider, currencySymbol);
              }
              if (showCreditUsage && index == 1) {
                return _buildCreditUsageCard(
                    context, accountProvider, currencySymbol);
              }
              final account = accounts[index - leadingCount];
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
            UtilityFunction.formatMoney(netWorth,
                symbol: currencySymbol, showDecimals: true),
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
                      symbol: currencySymbol, showDecimals: true),
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
                      symbol: currencySymbol, showDecimals: true),
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

  /// Combined usage across every credit card that has a limit: total used of
  /// total limit, an overall utilization bar, and remaining credit.
  Widget _buildCreditUsageCard(
    BuildContext context,
    AccountProvider provider,
    String currencySymbol,
  ) {
    final used = provider.totalCreditUsed;
    final limit = provider.totalCreditLimit;
    final available = provider.totalCreditAvailable;
    final util = limit > 0 ? used / limit : 0.0;
    final pct = util.clamp(0.0, 1.0);
    final over = util > 1.0;
    final barColor = (over || pct >= 0.9)
        ? AppColors.negative
        : (pct >= 0.5 ? AppColors.warning : AppColors.positive);

    String money(double v) => UtilityFunction.formatMoney(v,
        symbol: currencySymbol, showDecimals: true);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: barColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card_rounded,
                  size: 15, color: context.textSecondary),
              const SizedBox(width: 6),
              Text(
                'CREDIT CARD USAGE',
                style: AppTextStyles.caption.copyWith(
                  color: context.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                over ? 'Over limit' : '${(util * 100).round()}%',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: barColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                money(used),
                style: AppTextStyles.h2.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'of ${money(limit)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: context.textSecondary.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${money(available)} available to spend',
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
            ),
          ),
        ],
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
    final isLiability = account.isLiability;
    // For credit cards with a limit set: available = limit − owed, shown as the
    // headline figure counting down from the limit.
    final available = account.availableCredit;
    final utilization = account.creditUtilization;
    final hasLimit = available != null && utilization != null;

    // Per-account currency: show the balance in the account's own currency,
    // with a base-currency conversion underneath when they differ.
    final acctSymbol = account.currency.isEmpty
        ? currencySymbol
        : currencySymbolForCode(account.currency);
    final showConversion = account.currency.isNotEmpty &&
        account.currency != accountProvider.baseCurrency;
    final headlineNative = hasLimit ? available : account.currentBalance;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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

                  // Name and type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                account.name,
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                                  color:
                                      context.appAccent.withValues(alpha: 0.1),
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
                          (isLiability && !hasLimit)
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

                  // Headline figure: available credit (CC w/ limit), amount
                  // owed (CC w/o limit), or current balance (assets).
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        UtilityFunction.formatMoney(
                          headlineNative,
                          symbol: acctSymbol,
                          showDecimals: true,
                        ),
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: hasLimit
                              ? (available < 0
                                  ? AppColors.negative
                                  : AppColors.positive)
                              : (isLiability
                                  ? AppColors.negative
                                  : (account.currentBalance < 0
                                      ? AppColors.negative
                                      : context.textPrimary)),
                        ),
                      ),
                      Text(
                        showConversion
                            ? '${account.currency} · ≈ ${UtilityFunction.formatMoney(accountProvider.balanceInBase(account), symbol: currencySymbol, showDecimals: true)}'
                            : (hasLimit
                                ? 'available'
                                : (isLiability
                                    ? 'balance owed'
                                    : 'available')),
                        style: AppTextStyles.caption.copyWith(
                          color: context.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Utilization bar for credit cards with a limit.
              if (hasLimit) ...[
                const SizedBox(height: 14),
                _creditUtilizationBar(
                    context, account, utilization, acctSymbol),
              ],

              // Pay action for credit cards: records a transfer from a bank/
              // cash account onto this card (the real-app way to pay a card).
              if (isLiability) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        showTransferSheet(context, toAccountId: account.id),
                    style: TextButton.styleFrom(
                      foregroundColor: context.appAccent,
                      backgroundColor:
                          context.appAccent.withValues(alpha: 0.10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.south_west_rounded, size: 16),
                    label: const Text('Pay card'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _creditUtilizationBar(
    BuildContext context,
    Account account,
    double utilization,
    String currencySymbol,
  ) {
    final pct = utilization.clamp(0.0, 1.0);
    final over = utilization > 1.0;
    final owed = account.currentBalance;
    final limit = account.creditLimit!;

    final Color barColor = (over || pct >= 0.9)
        ? AppColors.negative
        : (pct >= 0.5 ? AppColors.warning : AppColors.positive);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: context.textSecondary.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${UtilityFunction.formatMoney(owed, symbol: currencySymbol, showDecimals: true)}'
              ' of '
              '${UtilityFunction.formatMoney(limit, symbol: currencySymbol, showDecimals: true)} used',
              style: AppTextStyles.caption.copyWith(
                color: context.textSecondary,
              ),
            ),
            Text(
              over ? 'Over limit' : '${(utilization * 100).round()}%',
              style: AppTextStyles.caption.copyWith(
                color: barColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
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
