import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utilities/constants.dart';
import '../../utilities/theme_helper.dart';
import '../../utilities/functions.dart';
import '../../screens/all_transactions_screen.dart';

class AccountsPieChart extends StatefulWidget {
  final double totalExpenses;
  final DateTime currentMonth;

  const AccountsPieChart({
    super.key,
    required this.totalExpenses,
    required this.currentMonth,
  });

  @override
  State<AccountsPieChart> createState() => _AccountsPieChartState();
}

class _AccountsPieChartState extends State<AccountsPieChart>
    with SingleTickerProviderStateMixin {
  int? _touchedIndex;
  Set<int> _selectedAccountIds = {};
  bool _initialized = false;

  // Animation controller for entrance animation
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    );

    // Start animation after a small delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeSelection(List<Account> accounts) {
    if (!_initialized) {
      _selectedAccountIds = accounts.map((a) => a.id!).toSet();
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AccountProvider, TransactionProvider, SettingsProvider>(
      builder: (context, accountProvider, transactionProvider, settingsProvider,
          child) {
        final currencySymbol = settingsProvider.currencySymbol;
        final accounts = accountProvider.accounts;
        final transactions = transactionProvider.transactions;

        // 1. Calculate spending per account
        final Map<int, double> accountSpending = {};

        // Initialize 0
        for (var account in accounts) {
          if (account.id != null) {
            accountSpending[account.id!] = 0.0;
          }
        }

        // Track Unknown/Deleted accounts
        double unknownSpending = 0.0;

        // Aggregate expenses
        for (var transaction in transactions) {
          if (transaction.isExpense) {
            final accId = transaction.accountId;
            if (accountSpending.containsKey(accId)) {
              accountSpending[accId] =
                  (accountSpending[accId] ?? 0.0) + transaction.amount;
            } else {
              unknownSpending += transaction.amount;
            }
          }
        }

        // 2. Prepare list of accounts
        final spendingAccounts = List<Account>.from(accounts);

        // Add virtual unknown account if needed
        if (unknownSpending > 0) {
          final now = DateTime.now();
          final unknownAccount = Account(
            id: -1, // Special ID
            name: 'Unknown Account',
            icon: 'assets/categories/other.png', // Fallback icon
            color: 'FF9E9E9E', // Grey
            initialBalance: 0.0,
            currentBalance: 0.0,
            createdOn: now,
            modifiedOn: now,
          );
          spendingAccounts.add(unknownAccount);
          accountSpending[-1] = unknownSpending;
        }

        spendingAccounts.sort((a, b) {
          final spentA = accountSpending[a.id] ?? 0.0;
          final spentB = accountSpending[b.id] ?? 0.0;
          return spentB.compareTo(spentA); // Descending
        });

        if (!_initialized) {
          _initializeSelection(spendingAccounts);
        }

        // 3. Filter based on selection
        final allSelectedAccounts = spendingAccounts
            .where((acc) => _selectedAccountIds.contains(acc.id))
            .toList();

        final displayAccounts = allSelectedAccounts.take(6).toList();

        // Calculate total from ALL selected accounts, not just top 6
        final filteredTotal = allSelectedAccounts.fold(
            0.0, (sum, acc) => sum + (accountSpending[acc.id] ?? 0.0));

        final hasSelection = displayAccounts.isNotEmpty;
        final isAnimating = _animationController.isAnimating;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spending by Account',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (hasSelection)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      UtilityFunction.addCommaWithSign(widget.totalExpenses,
                          currencySymbol: currencySymbol),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // Pie Chart
            if (hasSelection && filteredTotal > 0)
              SizedBox(
                height: 260,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Stack(
                      children: [
                        PieChart(
                          PieChartData(
                            sections: _buildPieChartSections(displayAccounts,
                                filteredTotal, accountSpending),
                            sectionsSpace: 2,
                            centerSpaceRadius: 75,
                            borderData: FlBorderData(show: false),
                            startDegreeOffset: 270,
                            pieTouchData: PieTouchData(
                              touchCallback: (event, pieTouchResponse) {
                                if (event is FlTapUpEvent &&
                                    pieTouchResponse != null) {
                                  final index = pieTouchResponse
                                      .touchedSection?.touchedSectionIndex;

                                  if (index != null &&
                                      index >= 0 &&
                                      index < displayAccounts.length) {
                                    // Only provide visual feedback, no navigation
                                    setState(() {
                                      _touchedIndex = index;
                                    });
                                  }
                                } else if (event is FlPanEndEvent ||
                                    event is FlTapUpEvent) {
                                  // Reset touched state when user stops touching
                                  setState(() {
                                    _touchedIndex = null;
                                  });
                                }
                              },
                            ),
                          ),
                          duration: isAnimating
                              ? Duration.zero
                              : const Duration(milliseconds: 150),
                          curve: Curves.linear,
                        ),
                        // Center display (Total or Selected) - Tappable for all transactions
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              // Navigate to all transactions for the selected month
                              final startDate = DateTime(
                                widget.currentMonth.year,
                                widget.currentMonth.month,
                                1,
                              );
                              final endDate = DateTime(
                                widget.currentMonth.year,
                                widget.currentMonth.month + 1,
                                0,
                              );

                              // Determine if we should filter by account
                              final int? accountId = _touchedIndex != null &&
                                      _touchedIndex! >= 0 &&
                                      _touchedIndex! < displayAccounts.length
                                  ? displayAccounts[_touchedIndex!].id
                                  : null;

                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation,
                                          secondaryAnimation) =>
                                      AllTransactionsScreen(
                                    initialStartDate: startDate,
                                    initialEndDate: endDate,
                                    initialAccountId:
                                        accountId, // Filter by account if touched
                                    hideFiltersInitially: true,
                                  ),
                                  transitionsBuilder: (context, animation,
                                      secondaryAnimation, child) {
                                    // Same premium animation for consistency
                                    const slideBegin = Offset(0.15, 0.0);
                                    const slideEnd = Offset.zero;

                                    final slideCurve = CurvedAnimation(
                                      parent: animation,
                                      curve: const Interval(0.0, 1.0,
                                          curve: Curves.easeOutCubic),
                                    );

                                    final fadeCurve = CurvedAnimation(
                                      parent: animation,
                                      curve: const Interval(0.0, 0.5,
                                          curve: Curves.easeIn),
                                    );

                                    final scaleCurve = CurvedAnimation(
                                      parent: animation,
                                      curve: const Interval(0.0, 0.8,
                                          curve: Curves.easeOutBack),
                                    );

                                    return SlideTransition(
                                      position: Tween<Offset>(
                                        begin: slideBegin,
                                        end: slideEnd,
                                      ).animate(slideCurve),
                                      child: FadeTransition(
                                        opacity: fadeCurve,
                                        child: ScaleTransition(
                                          scale: Tween<double>(
                                                  begin: 0.95, end: 1.0)
                                              .animate(scaleCurve),
                                          child: child,
                                        ),
                                      ),
                                    );
                                  },
                                  transitionDuration:
                                      const Duration(milliseconds: 500),
                                ),
                              ).then((_) {
                                // Reset touched state when returning
                                if (mounted) {
                                  setState(() {
                                    _touchedIndex = null;
                                  });
                                }
                              });
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _touchedIndex != null &&
                                          _touchedIndex! >= 0 &&
                                          _touchedIndex! <
                                              displayAccounts.length
                                      ? displayAccounts[_touchedIndex!].name
                                      : 'Total',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    letterSpacing: 0.2,
                                    color: context.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _touchedIndex != null &&
                                          _touchedIndex! >= 0 &&
                                          _touchedIndex! <
                                              displayAccounts.length
                                      ? UtilityFunction.addCommaWithSign(
                                          accountSpending[displayAccounts[
                                                      _touchedIndex!]
                                                  .id] ??
                                              0.0,
                                          currencySymbol: currencySymbol)
                                      : UtilityFunction.addCommaWithSign(
                                          widget.totalExpenses,
                                          currencySymbol: currencySymbol),
                                  style: AppTextStyles.h2.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 26,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // View Details hint
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.touch_app,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'View Details',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              )
            else
              Container(
                height: 260,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.appSurfaceLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.divider.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pie_chart_outline,
                      size: 48,
                      color: context.textSecondary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      filteredTotal > 0
                          ? 'No Accounts Selected'
                          : 'No Spending Data',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 28),

            // Accounts List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: spendingAccounts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final account = spendingAccounts[index];
                final spentAmount = accountSpending[account.id] ?? 0.0;
                final percentage = filteredTotal > 0
                    ? (spentAmount / filteredTotal * 100)
                    : 0.0;
                final isSelected = _selectedAccountIds.contains(account.id);
                final color = Color(Account.colorFromHex(account.color));

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedAccountIds.remove(account.id);
                      } else {
                        _selectedAccountIds.add(account.id!);
                      }
                      _touchedIndex = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.appBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? color.withValues(alpha: 0.3)
                            : AppColors.divider.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Checkbox
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedAccountIds.add(account.id!);
                                } else {
                                  _selectedAccountIds.remove(account.id);
                                }
                                _touchedIndex = null;
                              });
                            },
                            activeColor: color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.15)
                                : AppColors.divider.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Image.asset(
                            account.icon,
                            width: 20,
                            height: 20,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.account_balance_wallet,
                              size: 20,
                              color: isSelected
                                  ? color
                                  : context.textSecondary
                                      .withValues(alpha: 0.3),
                            ),
                            colorBlendMode:
                                isSelected ? null : BlendMode.saturation,
                            color: isSelected
                                ? null
                                : context.textSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.name,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color:
                                      isSelected ? null : context.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (isSelected && spentAmount > 0)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: percentage / 100,
                                    backgroundColor: AppColors.divider
                                        .withValues(alpha: 0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      color,
                                    ),
                                    minHeight: 4,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Balance (Spent)
                        Text(
                          UtilityFunction.addCommaWithSign(spentAmount,
                              currencySymbol: currencySymbol),
                          style: AppTextStyles.h3.copyWith(
                            color: isSelected ? color : context.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
      List<Account> accounts, double totalVisible, Map<int, double> spending) {
    if (totalVisible <= 0) {
      return [
        PieChartSectionData(
          color: Colors.transparent,
          value: 100,
          radius: 45,
          showTitle: false,
        ),
      ];
    }

    final sections = <PieChartSectionData>[];
    final anim = _animation.value;

    for (int i = 0; i < accounts.length; i++) {
      final acc = accounts[i];
      final spentAmount = spending[acc.id] ?? 0.0;
      if (spentAmount <= 0) continue;

      final isTouched = _touchedIndex == i;
      final radius = isTouched ? 55.0 : 50.0;
      final percentage =
          totalVisible > 0 ? (spentAmount / totalVisible * 100) : 0.0;
      final color = Color(Account.colorFromHex(acc.color));

      sections.add(PieChartSectionData(
        color: color,
        value: spentAmount,
        radius: radius,
        showTitle: percentage > 4,
        title: '${percentage.round()}%',
        titleStyle: AppTextStyles.bodySmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: isTouched ? 14 : 12,
        ),
        badgeWidget: _touchedIndex == i ? _buildBadge(acc.icon) : null,
        badgePositionPercentageOffset: .98,
      ));
    }

    // Dummy section for sweep animation
    if (anim < 1.0 && anim > 0.0) {
      final dummyVal = totalVisible * (1.0 - anim) / anim;
      sections.add(PieChartSectionData(
        color: Colors.transparent,
        value: dummyVal,
        radius: 48,
        showTitle: false,
      ));
    } else if (anim <= 0.0) {
      return [
        PieChartSectionData(
          color: Colors.transparent,
          value: 100,
          radius: 50,
          showTitle: false,
        ),
      ];
    }

    return sections;
  }

  Widget _buildBadge(String iconPath) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Image.asset(
        iconPath,
        width: 16,
        height: 16,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.account_balance_wallet,
          size: 16,
        ),
      ),
    );
  }
}
