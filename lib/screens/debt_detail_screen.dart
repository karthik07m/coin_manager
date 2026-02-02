import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/debt_provider.dart';
import '../providers/settings_provider.dart';
import '../models/debt.dart';
import '../models/debt_payment.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';
import '../widgets/calculator_field.dart';
import 'debt_form_screen.dart';

class DebtDetailScreen extends StatefulWidget {
  static const String routeName = '/debt-detail';
  final String debtId;

  const DebtDetailScreen({super.key, required this.debtId});

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  List<DebtPayment> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
  }

  Future<void> _loadPaymentHistory() async {
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final payments = await debtProvider.getPaymentHistory(widget.debtId);
    setState(() {
      _payments = payments;
      _isLoading = false;
    });
  }

  Future<void> _showRecordPaymentDialog(Debt debt) async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    DateTime paymentDate = DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.textSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const SizedBox(height: 8),
                Text('Record Payment', style: AppTextStyles.h3),
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Amount',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CalculatorTextFormField(
                        controller: amountController,
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Payment Date',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: paymentDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() {
                              paymentDate = picked;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: context.appBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  context.textSecondary.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('MMM dd, yyyy').format(paymentDate),
                                style: AppTextStyles.bodyLarge,
                              ),
                              const Spacer(),
                              Icon(Icons.chevron_right_rounded,
                                  color: context.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Notes (Optional)',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        style: AppTextStyles.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'Add a note...',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: context.textSecondary.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: context.appBackground,
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color:
                                  context.textSecondary.withValues(alpha: 0.1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color:
                                  context.textSecondary.withValues(alpha: 0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: context.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                final amountText =
                                    amountController.text.replaceAll(',', '');
                                if (amountText.isEmpty) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter an amount'),
                                      backgroundColor: AppColors.negative,
                                    ),
                                  );
                                  return;
                                }

                                final amount = double.tryParse(amountText);
                                if (amount == null || amount <= 0) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Please enter a valid amount'),
                                      backgroundColor: AppColors.negative,
                                    ),
                                  );
                                  return;
                                }

                                final remaining = debt.getRemainingAmount();
                                final currencySymbol =
                                    Provider.of<SettingsProvider>(context,
                                            listen: false)
                                        .currencySymbol;
                                if (amount > remaining) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Amount cannot exceed remaining balance of ${UtilityFunction.addCommaWithSign(remaining, currencySymbol: currencySymbol)}'),
                                      backgroundColor: AppColors.negative,
                                    ),
                                  );
                                  return;
                                }

                                final payment = DebtPayment.createNew(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  debtId: debt.id,
                                  amount: amount,
                                  paymentDate: paymentDate,
                                  notes: notesController.text.isNotEmpty
                                      ? notesController.text
                                      : null,
                                );

                                final debtProvider = Provider.of<DebtProvider>(
                                    this.context,
                                    listen: false);
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(context);

                                final success = await debtProvider
                                    .recordPayment(debt.id, payment);

                                if (!context.mounted) return;
                                navigator.pop();
                                if (success) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Payment recorded successfully'),
                                      backgroundColor: AppColors.positive,
                                    ),
                                  );
                                  _loadPaymentHistory();
                                } else {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to record payment'),
                                      backgroundColor: AppColors.negative,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Record Payment',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markAsPaid() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        title: Text('Mark as Paid', style: AppTextStyles.h3),
        content: Text(
          'Are you sure you want to mark this debt as fully paid?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Mark as Paid',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.positive,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final debtProvider = Provider.of<DebtProvider>(context, listen: false);
      final success = await debtProvider.markAsPaid(widget.debtId);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debt marked as paid'),
            backgroundColor: AppColors.positive,
          ),
        );
        _loadPaymentHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark as paid'),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        title: const Text('Debt Details', style: AppTextStyles.h3),
        centerTitle: true,
        elevation: 0,
        actions: [
          Consumer<DebtProvider>(
            builder: (context, debtProvider, child) {
              final debt = debtProvider.getDebtById(widget.debtId);
              if (debt == null) return const SizedBox.shrink();
              return IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DebtFormScreen(
                        debtId: debt.id,
                        isLiability: debt.isLiability,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
              );
            },
          ),
        ],
      ),
      body: Consumer2<DebtProvider, SettingsProvider>(
        builder: (context, debtProvider, settingsProvider, child) {
          final debt = debtProvider.getDebtById(widget.debtId);
          final currencySymbol = settingsProvider.currencySymbol;

          if (debt == null) {
            return const Center(
              child: Text('Debt not found'),
            );
          }

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

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor,
                          statusColor.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                debt.isLiability
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    debt.title,
                                    style: AppTextStyles.h2.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    debt.debtorName,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Remaining Balance',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          UtilityFunction.addCommaWithSign(remaining,
                              currencySymbol: currencySymbol),
                          style: AppTextStyles.h1.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 36,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'of ${UtilityFunction.addCommaWithSign(debt.amount, currencySymbol: currencySymbol)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${progress.toStringAsFixed(0)}% paid',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Details Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.appSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Details',
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (debt.dueDate != null)
                          _buildDetailRow(
                            'Due Date',
                            DateFormat('MMM dd, yyyy').format(debt.dueDate!),
                            Icons.calendar_today,
                          ),
                        _buildDetailRow(
                          'Status',
                          debt.status.name.toUpperCase(),
                          Icons.info_outline,
                        ),
                        if (debt.interestRate != null)
                          _buildDetailRow(
                            'Interest Rate',
                            '${debt.interestRate}%',
                            Icons.percent,
                          ),
                        if (debt.isRecurring) ...[
                          const Divider(height: 24),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.repeat_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'MONTHLY RECURRING',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (debt.recurringAmount != null) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'Recurring Amount',
                              UtilityFunction.addCommaWithSign(
                                  debt.recurringAmount!,
                                  currencySymbol: currencySymbol),
                              Icons.payments,
                            ),
                          ],
                        ],
                        if (debt.notes != null) ...[
                          const Divider(height: 24),
                          Text(
                            'Notes',
                            style: AppTextStyles.caption.copyWith(
                              color: context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            debt.notes!,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment History
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment History',
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_payments.length} ${_payments.length == 1 ? 'payment' : 'payments'}',
                        style: AppTextStyles.caption.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_payments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: context.appSurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 48,
                              color:
                                  context.textSecondary.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No payments recorded yet',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _payments.length,
                      itemBuilder: (context, index) {
                        final payment = _payments[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.appSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.positive
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.check_circle,
                                  color: AppColors.positive,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      UtilityFunction.addCommaWithSign(
                                          payment.amount,
                                          currencySymbol: currencySymbol),
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          DateFormat('MMM dd, yyyy')
                                              .format(payment.paymentDate),
                                          style: AppTextStyles.caption.copyWith(
                                            color: context.textSecondary,
                                          ),
                                        ),
                                        if (payment.notes != null) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            '• ${payment.notes}',
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              color: context.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Consumer<DebtProvider>(
        builder: (context, debtProvider, child) {
          final debt = debtProvider.getDebtById(widget.debtId);
          if (debt == null || debt.status == DebtStatus.paid) {
            return const SizedBox.shrink();
          }

          return Container(
            padding: EdgeInsets.only(
              left: AppDimensions.spacing16,
              right: AppDimensions.spacing16,
              top: AppDimensions.spacing8,
              bottom: MediaQuery.of(context).padding.bottom +
                  AppDimensions.spacing8,
            ),
            decoration: BoxDecoration(
              color: context.appSurface,
              border: Border(
                top: BorderSide(
                  color: context.textSecondary.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _showRecordPaymentDialog(debt),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.payment_rounded, size: 18),
                      label: const Text(
                        'Record Payment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: AppColors.positive.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _markAsPaid,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    color: AppColors.positive,
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    tooltip: 'Mark as Paid',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
