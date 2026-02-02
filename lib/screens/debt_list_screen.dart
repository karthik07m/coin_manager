import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/debt_provider.dart';
import '../providers/settings_provider.dart';
import '../models/debt.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';
import 'debt_form_screen.dart';
import 'debt_detail_screen.dart';

class DebtListScreen extends StatefulWidget {
  static const String routeName = '/debts';

  const DebtListScreen({super.key});

  @override
  State<DebtListScreen> createState() => _DebtListScreenState();
}

class _DebtListScreenState extends State<DebtListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DebtStatus _selectedStatus = DebtStatus.active;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DebtProvider>(context, listen: false).loadDebtsFromDB();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        title: const Text('Debt Tracker', style: AppTextStyles.h3),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing16,
                ),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusLarge),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusLarge),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: context.textSecondary,
                  labelStyle: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  tabs: const [
                    Tab(text: 'Money I Owe'),
                    Tab(text: 'Owed to Me'),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spacing12),
              // Status Filter
              _buildStatusFilter(),
              const SizedBox(height: AppDimensions.spacing8),
            ],
          ),
        ),
      ),
      body: Consumer2<DebtProvider, SettingsProvider>(
        builder: (context, debtProvider, settingsProvider, child) {
          final currencySymbol = settingsProvider.currencySymbol;
          return TabBarView(
            controller: _tabController,
            children: [
              _buildDebtList(true, debtProvider, currencySymbol), // Liabilities
              _buildDebtList(
                  false, debtProvider, currencySymbol), // Receivables
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DebtFormScreen(
                isLiability: _tabController.index == 0,
              ),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        elevation: 4,
        highlightElevation: 2,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Add Debt',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildStatusChip('Active', DebtStatus.active, AppColors.primary),
          const SizedBox(width: 8),
          _buildStatusChip('Overdue', DebtStatus.overdue, AppColors.negative),
          const SizedBox(width: 8),
          _buildStatusChip('Paid', DebtStatus.paid, AppColors.positive),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, DebtStatus status, Color color) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: isSelected ? Colors.white : context.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = status;
        });
      },
      backgroundColor: context.appSurface,
      selectedColor: color,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color:
            isSelected ? color : context.textSecondary.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildDebtList(
      bool isLiability, DebtProvider debtProvider, String currencySymbol) {
    final debts = debtProvider
        .filterByTypeAndStatus(
          isLiability: isLiability,
          status: _selectedStatus,
        )
        .toList()
      ..sort((a, b) {
        // Sort by due date, then by modified date
        if (a.dueDate != null && b.dueDate != null) {
          return a.dueDate!.compareTo(b.dueDate!);
        } else if (a.dueDate != null) {
          return -1;
        } else if (b.dueDate != null) {
          return 1;
        }
        return b.modifiedOn.compareTo(a.modifiedOn);
      });

    if (debts.isEmpty) {
      return _buildEmptyState(isLiability);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await debtProvider.loadDebtsFromDB();
      },
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.spacing16,
          AppDimensions.spacing16,
          AppDimensions.spacing16,
          100,
        ),
        itemCount: debts.length,
        itemBuilder: (context, index) {
          final debt = debts[index];
          return _buildDebtCard(debt, currencySymbol);
        },
      ),
    );
  }

  Widget _buildDebtCard(Debt debt, String currencySymbol) {
    final remaining = debt.getRemainingAmount();
    final progress = debt.getProgressPercentage();

    Color statusColor;
    if (debt.status == DebtStatus.paid) {
      statusColor = AppColors.positive;
    } else if (debt.status == DebtStatus.overdue) {
      statusColor = AppColors.negative;
    } else if (progress >= 80) {
      statusColor = AppColors.warning;
    } else {
      statusColor = AppColors.primary;
    }

    final isPastDue = debt.dueDate != null &&
        DateTime.now().isAfter(debt.dueDate!) &&
        debt.status != DebtStatus.paid;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DebtDetailScreen(debtId: debt.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      debt.isLiability
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and Debtor
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.title,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          debt.debtorName,
                          style: AppTextStyles.caption.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                        if (debt.isRecurring) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.repeat_rounded,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'RECURRING',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        UtilityFunction.addCommaWithSign(remaining,
                            currencySymbol: currencySymbol),
                        style: AppTextStyles.h3.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'of ${UtilityFunction.addCommaWithSign(debt.amount, currencySymbol: currencySymbol)}',
                        style: AppTextStyles.caption.copyWith(
                          color: context.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      if (debt.amountPaid > 0)
                        Text(
                          'Paid: ${UtilityFunction.addCommaWithSign(debt.amountPaid, currencySymbol: currencySymbol)}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.positive,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: AppColors.divider.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 8,
                ),
              ),

              const SizedBox(height: 12),

              // Footer Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Progress text
                  Text(
                    '${progress.toStringAsFixed(0)}% paid',
                    style: AppTextStyles.caption.copyWith(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  // Due date or status
                  if (debt.dueDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPastDue
                            ? AppColors.negative.withValues(alpha: 0.15)
                            : AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: isPastDue ? AppColors.negative : statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd, yyyy').format(debt.dueDate!),
                            style: AppTextStyles.caption.copyWith(
                              color:
                                  isPastDue ? AppColors.negative : statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        debt.status.name.toUpperCase(),
                        style: AppTextStyles.caption.copyWith(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildEmptyState(bool isLiability) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLiability ? Icons.money_off : Icons.payments,
              size: 80,
              color: context.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppDimensions.spacing20),
            Text(
              'No ${_selectedStatus.name} debts',
              style: AppTextStyles.h3.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing8),
            Text(
              isLiability
                  ? 'Track money you need to pay back'
                  : 'Track money others owe you',
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.textSecondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
