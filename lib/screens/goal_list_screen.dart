import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/goal_provider.dart';
import '../providers/settings_provider.dart';
import '../models/goal.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';
import 'goal_form_screen.dart';
import 'goal_detail_screen.dart';

enum _GoalFilter { all, active, achieved }

class GoalListScreen extends StatefulWidget {
  static const String routeName = '/goals';

  const GoalListScreen({super.key});

  @override
  State<GoalListScreen> createState() => _GoalListScreenState();
}

class _GoalListScreenState extends State<GoalListScreen> {
  _GoalFilter _selectedFilter = _GoalFilter.active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GoalProvider>(context, listen: false).loadGoalsFromDB();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        title: const Text('Goals', style: AppTextStyles.h3),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.spacing8),
            child: _buildFilterBar(),
          ),
        ),
      ),
      body: Consumer2<GoalProvider, SettingsProvider>(
        builder: (context, goalProvider, settingsProvider, child) {
          final currencySymbol = settingsProvider.currencySymbol;
          return _buildGoalList(goalProvider, currencySymbol);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GoalFormScreen()),
          );
        },
        backgroundColor: context.appAccent,
        elevation: 4,
        highlightElevation: 2,
        icon: Icon(Icons.add_rounded,
            color: Theme.of(context).colorScheme.onPrimary, size: 22),
        label: Text(
          'Add Goal',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', _GoalFilter.all, context.appAccent),
          const SizedBox(width: 8),
          _buildFilterChip('Active', _GoalFilter.active, context.appAccent),
          const SizedBox(width: 8),
          _buildFilterChip(
              'Achieved', _GoalFilter.achieved, AppColors.positive),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, _GoalFilter filter, Color color) {
    final isSelected = _selectedFilter == filter;
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
          _selectedFilter = filter;
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

  Widget _buildGoalList(GoalProvider goalProvider, String currencySymbol) {
    List<Goal> goals;
    switch (_selectedFilter) {
      case _GoalFilter.active:
        goals = goalProvider.activeGoals;
        break;
      case _GoalFilter.achieved:
        goals = goalProvider.achievedGoals;
        break;
      case _GoalFilter.all:
        goals = goalProvider.goals;
        break;
    }

    goals = [...goals]
      ..sort((a, b) {
        if (a.targetDate != null && b.targetDate != null) {
          return a.targetDate!.compareTo(b.targetDate!);
        } else if (a.targetDate != null) {
          return -1;
        } else if (b.targetDate != null) {
          return 1;
        }
        return b.modifiedOn.compareTo(a.modifiedOn);
      });

    if (goals.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await goalProvider.loadGoalsFromDB();
      },
      color: context.appAccent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.spacing16,
          AppDimensions.spacing16,
          AppDimensions.spacing16,
          100,
        ),
        itemCount: goals.length,
        itemBuilder: (context, index) {
          final goal = goals[index];
          return _buildGoalCard(goal, currencySymbol);
        },
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
      return 'Target is today';
    } else if (days == 1) {
      return 'Target is tomorrow';
    } else if (days <= 30) {
      return '$days days left';
    }
    return null;
  }

  Widget _buildGoalCard(Goal goal, String currencySymbol) {
    final remaining = goal.getRemainingAmount();
    final progress = goal.getProgressPercentage();
    final isPastTarget = goal.targetDate != null &&
        DateTime.now().isAfter(goal.targetDate!) &&
        !goal.isAchieved;

    final Color statusColor =
        goal.isAchieved ? AppColors.positive : context.appAccent;

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
              builder: (context) => GoalDetailScreen(goalId: goal.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      goal.isAchieved
                          ? Icons.emoji_events_rounded
                          : Icons.savings_rounded,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          goal.isAchieved
                              ? 'Goal achieved'
                              : '${UtilityFunction.addCommaWithSign(remaining, currencySymbol: currencySymbol)} to go',
                          style: AppTextStyles.caption.copyWith(
                            color: goal.isAchieved
                                ? AppColors.positive
                                : context.textSecondary,
                            fontWeight: goal.isAchieved
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        UtilityFunction.addCommaWithSign(goal.currentAmount,
                            currencySymbol: currencySymbol),
                        style: AppTextStyles.h3.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'of ${UtilityFunction.addCommaWithSign(goal.targetAmount, currencySymbol: currencySymbol)}',
                        style: AppTextStyles.caption.copyWith(
                          color: context.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progress.toStringAsFixed(0)}% saved',
                    style: AppTextStyles.caption.copyWith(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (goal.targetDate != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isPastTarget
                                ? AppColors.negative.withValues(alpha: 0.15)
                                : context.appAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: isPastTarget
                                    ? AppColors.negative
                                    : statusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('MMM dd, yyyy')
                                    .format(goal.targetDate!),
                                style: AppTextStyles.caption.copyWith(
                                  color: isPastTarget
                                      ? AppColors.negative
                                      : statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_dueRelativeLabel(goal) != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _dueRelativeLabel(goal)!,
                            style: AppTextStyles.caption.copyWith(
                              color: isPastTarget
                                  ? AppColors.negative
                                  : context.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    )
                  else if (goal.isAchieved)
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
                        'ACHIEVED',
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.savings_outlined,
              size: 80,
              color: context.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppDimensions.spacing20),
            Text(
              _selectedFilter == _GoalFilter.achieved
                  ? 'No achieved goals yet'
                  : 'No goals yet',
              style: AppTextStyles.h3.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing8),
            Text(
              'Set a savings goal and track your progress toward it',
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
