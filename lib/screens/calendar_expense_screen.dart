import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/category_provider.dart';
import '../models/transaction.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';

class CalendarExpenseScreen extends StatefulWidget {
  final DateTime selectedMonth;

  const CalendarExpenseScreen({
    super.key,
    required this.selectedMonth,
  });

  @override
  State<CalendarExpenseScreen> createState() => _CalendarExpenseScreenState();
}

class _CalendarExpenseScreenState extends State<CalendarExpenseScreen>
    with TickerProviderStateMixin {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.selectedMonth;
    _selectedDay = DateTime.now();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();

    // Load transactions for initial month
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMonthData(_focusedDay);
    });
  }

  void _loadMonthData(DateTime month) {
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);

    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);

    transactionProvider.loadTransactionsFromDB(
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getExpenseColor(
      double amount, double maxAmount, BuildContext context) {
    if (amount == 0) return Colors.transparent;

    final intensity = (amount / maxAmount).clamp(0.0, 1.0);

    return Color.lerp(
      AppColors.negative.withValues(alpha: 0.2),
      AppColors.negative,
      intensity,
    )!;
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      double kAmount = amount / 1000;
      if (kAmount == kAmount.toInt()) {
        return '${kAmount.toInt()}k';
      }
      return '${kAmount.toStringAsFixed(1)}k';
    }
    return amount.toInt().toString();
  }

  void _showDayDetails(DateTime day, List<Transaction> transactions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DayDetailsSheet(
        day: day,
        transactions: transactions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Expense Calendar',
          style: AppTextStyles.h3.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, transactionProvider, child) {
          final transactionsByDay =
              transactionProvider.getTransactionsByDay(_focusedDay);

          // Calculate max expense for color intensity
          double maxExpense = 0;
          transactionsByDay.forEach((day, transactions) {
            final dayExpense = transactions
                .where((t) => t.isExpense)
                .fold(0.0, (sum, t) => sum + t.amount);
            if (dayExpense > maxExpense) maxExpense = dayExpense;
          });

          // Calculate monthly stats
          double totalExpenses = 0;
          int daysWithTransactions = 0;
          DateTime? highestDay;
          double highestAmount = 0;

          transactionsByDay.forEach((day, transactions) {
            final dayExpense = transactions
                .where((t) => t.isExpense)
                .fold(0.0, (sum, t) => sum + t.amount);
            totalExpenses += dayExpense;
            if (dayExpense > 0) daysWithTransactions++;
            if (dayExpense > highestAmount) {
              highestAmount = dayExpense;
              highestDay = day;
            }
          });

          final avgDaily = daysWithTransactions > 0
              ? totalExpenses / daysWithTransactions
              : 0;

          final currencySymbol =
              Provider.of<SettingsProvider>(context, listen: false)
                  .currencySymbol;

          return FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Calendar
                  Container(
                    margin: const EdgeInsets.all(AppDimensions.spacing16),
                    decoration: BoxDecoration(
                      color: context.appSurfaceLight,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusLarge),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: TableCalendar(
                      firstDay: DateTime(2020, 1, 1),
                      lastDay: DateTime(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      calendarFormat: CalendarFormat.month,
                      rowHeight: 64,
                      startingDayOfWeek: StartingDayOfWeek.sunday,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: AppTextStyles.h3.copyWith(
                          color: context.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left,
                          color: AppColors.primary,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right,
                          color: AppColors.primary,
                        ),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: AppTextStyles.caption.copyWith(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        weekendStyle: AppTextStyles.caption.copyWith(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        selectedDecoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        defaultTextStyle: AppTextStyles.bodyMedium.copyWith(
                          color: context.textPrimary,
                        ),
                        weekendTextStyle: AppTextStyles.bodyMedium.copyWith(
                          color: context.textPrimary,
                        ),
                        outsideTextStyle: AppTextStyles.bodyMedium.copyWith(
                          color: context.textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          final dayExpense =
                              transactionProvider.getDayExpenses(day);
                          final color =
                              _getExpenseColor(dayExpense, maxExpense, context);

                          return _buildDayCell(
                            day,
                            dayExpense,
                            color,
                            false,
                            false,
                            transactionsByDay[
                                        DateTime(day.year, day.month, day.day)]
                                    ?.isNotEmpty ??
                                false,
                            currencySymbol,
                          );
                        },
                        todayBuilder: (context, day, focusedDay) {
                          final dayExpense =
                              transactionProvider.getDayExpenses(day);
                          final color =
                              _getExpenseColor(dayExpense, maxExpense, context);

                          return _buildDayCell(
                            day,
                            dayExpense,
                            color,
                            true,
                            false,
                            transactionsByDay[
                                        DateTime(day.year, day.month, day.day)]
                                    ?.isNotEmpty ??
                                false,
                            currencySymbol,
                          );
                        },
                        selectedBuilder: (context, day, focusedDay) {
                          final dayExpense =
                              transactionProvider.getDayExpenses(day);
                          final color =
                              _getExpenseColor(dayExpense, maxExpense, context);

                          return _buildDayCell(
                            day,
                            dayExpense,
                            color,
                            false,
                            true,
                            transactionsByDay[
                                        DateTime(day.year, day.month, day.day)]
                                    ?.isNotEmpty ??
                                false,
                            currencySymbol,
                          );
                        },
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });

                        final transactions = transactionProvider
                            .getTransactionsForDay(selectedDay);
                        if (transactions.isNotEmpty) {
                          _showDayDetails(selectedDay, transactions);
                        }
                      },
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                        // Load transactions for new month
                        _loadMonthData(focusedDay);
                      },
                    ),
                  ),

                  // Summary Card
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing16,
                    ),
                    padding: const EdgeInsets.all(AppDimensions.spacing16),
                    decoration: BoxDecoration(
                      color: context.appSurfaceLight,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusLarge),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Summary',
                          style: AppTextStyles.h3.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacing16),
                        _buildSummaryRow(
                          context,
                          'Total Expenses',
                          UtilityFunction.addCommaWithSign(
                            totalExpenses,
                            currencySymbol:
                                Provider.of<SettingsProvider>(context)
                                    .currencySymbol,
                          ),
                          Icons.trending_down,
                          AppColors.negative,
                        ),
                        const SizedBox(height: AppDimensions.spacing12),
                        _buildSummaryRow(
                          context,
                          'Average/Day',
                          UtilityFunction.addCommaWithSign(
                            avgDaily.toDouble(),
                            currencySymbol:
                                Provider.of<SettingsProvider>(context)
                                    .currencySymbol,
                          ),
                          Icons.calendar_today,
                          AppColors.primary,
                        ),
                        if (highestDay != null) ...[
                          const SizedBox(height: AppDimensions.spacing12),
                          _buildSummaryRow(
                            context,
                            'Highest Day (${DateFormat('MMM d').format(highestDay!)})',
                            UtilityFunction.addCommaWithSign(
                              highestAmount,
                              currencySymbol:
                                  Provider.of<SettingsProvider>(context)
                                      .currencySymbol,
                            ),
                            Icons.arrow_upward,
                            AppColors.negative,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacing32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayCell(
    DateTime day,
    double expense,
    Color backgroundColor,
    bool isToday,
    bool isSelected,
    bool hasTransactions,
    String currencySymbol,
  ) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary
            : (expense > 0 ? backgroundColor : Colors.transparent),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        border: isToday
            ? Border.all(
                color: AppColors.primary,
                width: 2,
              )
            : null,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isSelected
                    ? Colors.white
                    : (expense > 0 ? Colors.white : context.textPrimary),
                fontWeight:
                    isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            if (expense > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$currencySymbol${_formatAmount(expense)}',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (hasTransactions && !isSelected)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: AppDimensions.spacing12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// Day Details Bottom Sheet
class _DayDetailsSheet extends StatelessWidget {
  final DateTime day;
  final List<Transaction> transactions;

  const _DayDetailsSheet({
    required this.day,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    final totalExpenses = transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalIncome = transactions
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusLarge),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing20),
                child: Column(
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d, y').format(day),
                      style: AppTextStyles.h3.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildTotalChip(
                          context,
                          'Expenses',
                          totalExpenses,
                          AppColors.negative,
                          settingsProvider.currencySymbol,
                        ),
                        _buildTotalChip(
                          context,
                          'Income',
                          totalIncome,
                          AppColors.positive,
                          settingsProvider.currencySymbol,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Transactions List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppDimensions.spacing16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final category = categoryProvider.categories.firstWhere(
                      (c) => c.id == transaction.categoryId,
                      orElse: () => categoryProvider.categories.first,
                    );

                    return Container(
                      margin: const EdgeInsets.only(
                          bottom: AppDimensions.spacing12),
                      padding: const EdgeInsets.all(AppDimensions.spacing12),
                      decoration: BoxDecoration(
                        color: context.appBackground,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        border: Border.all(
                          color: (transaction.isExpense
                                  ? AppColors.negative
                                  : AppColors.positive)
                              .withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Category Icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (transaction.isExpense
                                      ? AppColors.negative
                                      : AppColors.positive)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Image.asset(
                              category.icon,
                              width: 24,
                              height: 24,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacing12),

                          // Transaction Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  transaction.title,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  category.name,
                                  style: AppTextStyles.caption.copyWith(
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Amount
                          Text(
                            UtilityFunction.addCommaWithSign(
                              transaction.amount,
                              currencySymbol: settingsProvider.currencySymbol,
                            ),
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: transaction.isExpense
                                  ? AppColors.negative
                                  : AppColors.positive,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalChip(
    BuildContext context,
    String label,
    double amount,
    Color color,
    String currencySymbol,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            UtilityFunction.addCommaWithSign(
              amount,
              currencySymbol: currencySymbol,
            ),
            style: AppTextStyles.bodyLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
