import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/goal_provider.dart';
import '../providers/settings_provider.dart';
import '../models/goal.dart';
import '../models/goal_contribution.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';
import '../widgets/calculator_field.dart';
import 'goal_form_screen.dart';

class GoalDetailScreen extends StatefulWidget {
  static const String routeName = '/goal-detail';
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  List<GoalContribution> _contributions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContributionHistory();
  }

  Future<void> _loadContributionHistory() async {
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    final contributions = await goalProvider.getContributionHistory(widget.goalId);
    setState(() {
      _contributions = contributions;
      _isLoading = false;
    });
  }

  Future<void> _showAddContributionDialog(Goal goal) async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    DateTime contributionDate = DateTime.now();

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
                Text('Add Contribution', style: AppTextStyles.h3),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
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
                        'Date',
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
                            initialDate: contributionDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() {
                              contributionDate = picked;
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
                                  color: context.appAccent, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('MMM dd, yyyy')
                                    .format(contributionDate),
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
                            borderSide: BorderSide(
                              color: context.appAccent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 32),
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

                                final contribution =
                                    GoalContribution.createNew(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  goalId: goal.id,
                                  amount: amount,
                                  contributionDate: contributionDate,
                                  notes: notesController.text.isNotEmpty
                                      ? notesController.text
                                      : null,
                                );

                                final goalProvider = Provider.of<GoalProvider>(
                                    this.context,
                                    listen: false);
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(context);

                                final success = await goalProvider
                                    .recordContribution(goal.id, contribution);

                                if (!context.mounted) return;
                                navigator.pop();
                                if (success) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Contribution added successfully'),
                                      backgroundColor: AppColors.positive,
                                    ),
                                  );
                                  _loadContributionHistory();
                                } else {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Failed to add contribution'),
                                      backgroundColor: AppColors.negative,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.appAccent,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Add Contribution',
                                style: AppTextStyles.button,
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

  String? _dueRelativeLabel(Goal goal) {
    if (goal.isAchieved) return null;
    final days = goal.getDaysUntilTarget();
    if (days == null) return null;
    if (days < 0) {
      final n = -days;
      return '$n ${n == 1 ? 'day' : 'days'} past target';
    } else if (days == 0) {
      return 'target is today';
    } else if (days == 1) {
      return 'target is tomorrow';
    } else if (days <= 30) {
      return '$days days left';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        title: const Text('Goal Details', style: AppTextStyles.h3),
        centerTitle: true,
        elevation: 0,
        actions: [
          Consumer<GoalProvider>(
            builder: (context, goalProvider, child) {
              final goal = goalProvider.getGoalById(widget.goalId);
              if (goal == null) return const SizedBox.shrink();
              return IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GoalFormScreen(goalId: goal.id),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
              );
            },
          ),
        ],
      ),
      body: Consumer2<GoalProvider, SettingsProvider>(
        builder: (context, goalProvider, settingsProvider, child) {
          final goal = goalProvider.getGoalById(widget.goalId);
          final currencySymbol = settingsProvider.currencySymbol;

          if (goal == null) {
            return const Center(child: Text('Goal not found'));
          }

          final remaining = goal.getRemainingAmount();
          final progress = goal.getProgressPercentage();
          final statusColor =
              goal.isAchieved ? AppColors.positive : context.appAccent;

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
                                goal.isAchieved
                                    ? Icons.emoji_events_rounded
                                    : Icons.savings_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                goal.title,
                                style: AppTextStyles.h2.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          goal.isAchieved ? 'Saved' : 'Remaining',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          UtilityFunction.addCommaWithSign(
                              goal.isAchieved ? goal.currentAmount : remaining,
                              currencySymbol: currencySymbol),
                          style: AppTextStyles.h1.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 36,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'of ${UtilityFunction.addCommaWithSign(goal.targetAmount, currencySymbol: currencySymbol)} target',
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
                          '${progress.toStringAsFixed(0)}% saved',
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
                        if (goal.targetDate != null)
                          _buildDetailRow(
                            'Target Date',
                            _dueRelativeLabel(goal) != null
                                ? '${DateFormat('MMM dd, yyyy').format(goal.targetDate!)} (${_dueRelativeLabel(goal)})'
                                : DateFormat('MMM dd, yyyy')
                                    .format(goal.targetDate!),
                            Icons.calendar_today,
                          ),
                        _buildDetailRow(
                          'Status',
                          goal.isAchieved ? 'ACHIEVED' : 'IN PROGRESS',
                          Icons.info_outline,
                        ),
                        if (goal.notes != null) ...[
                          const Divider(height: 24),
                          Text(
                            'Notes',
                            style: AppTextStyles.caption.copyWith(
                              color: context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            goal.notes!,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Contribution History
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Contribution History',
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_contributions.length} ${_contributions.length == 1 ? 'entry' : 'entries'}',
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
                  else if (_contributions.isEmpty)
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
                              'No contributions recorded yet',
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
                      itemCount: _contributions.length,
                      itemBuilder: (context, index) {
                        final contribution = _contributions[index];
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
                                  Icons.add_circle,
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
                                          contribution.amount,
                                          currencySymbol: currencySymbol),
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          DateFormat('MMM dd, yyyy').format(
                                              contribution.contributionDate),
                                          style: AppTextStyles.caption.copyWith(
                                            color: context.textSecondary,
                                          ),
                                        ),
                                        if (contribution.notes != null) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            '• ${contribution.notes}',
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
      bottomNavigationBar: Consumer<GoalProvider>(
        builder: (context, goalProvider, child) {
          final goal = goalProvider.getGoalById(widget.goalId);
          if (goal == null || goal.isAchieved) {
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
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showAddContributionDialog(goal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appAccent,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Add Contribution',
                  style: AppTextStyles.button,
                ),
              ),
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
