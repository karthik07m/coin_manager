import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/goal_provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';
import '../screens/goal_list_screen.dart';

class GoalSummaryWidget extends StatelessWidget {
  const GoalSummaryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<GoalProvider, SettingsProvider>(
      builder: (context, goalProvider, settingsProvider, child) {
        final activeGoals = goalProvider.activeGoals;
        final achievedCount = goalProvider.achievedGoals.length;
        final totalSaved = goalProvider.totalSaved;
        final totalTarget = goalProvider.totalTarget;
        final currencySymbol = settingsProvider.currencySymbol;
        final hasGoals = goalProvider.goals.isNotEmpty;
        final overallProgress =
            totalTarget > 0 ? (totalSaved / totalTarget * 100).clamp(0, 100) : 0.0;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GoalListScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.spacing20),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: Border.all(
                color: context.appAccent.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.appAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.savings_rounded,
                            color: context.appAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Goals',
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (activeGoals.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.appAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${activeGoals.length} active',
                          style: AppTextStyles.caption.copyWith(
                            color: context.appAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacing16),
                if (!hasGoals)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.spacing8),
                      child: Text(
                        'No goals yet • Tap to add one',
                        style: AppTextStyles.caption.copyWith(
                          color: context.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  )
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        UtilityFunction.addCommaWithSign(totalSaved,
                            currencySymbol: currencySymbol),
                        style: AppTextStyles.h2.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.positive,
                        ),
                      ),
                      Text(
                        'of ${UtilityFunction.addCommaWithSign(totalTarget, currencySymbol: currencySymbol)}',
                        style: AppTextStyles.caption.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: overallProgress / 100,
                      backgroundColor: AppColors.divider.withValues(alpha: 0.2),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(context.appAccent),
                      minHeight: 8,
                    ),
                  ),
                  if (achievedCount > 0) ...[
                    const SizedBox(height: AppDimensions.spacing12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.positive.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.emoji_events_rounded,
                            size: 18,
                            color: AppColors.positive,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$achievedCount ${achievedCount == 1 ? 'goal' : 'goals'} achieved',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.positive,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
