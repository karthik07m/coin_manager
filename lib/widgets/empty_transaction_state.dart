import 'package:flutter/material.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

class EmptyTransactionState extends StatelessWidget {
  const EmptyTransactionState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.appSurfaceLight.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Icon(
              Icons
                  .receipt_long_rounded, // Rounded version for better aesthetics
              size: 48,
              color: context.textSecondary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Transactions',
            style: AppTextStyles.h3.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t made any transactions\nfor this month yet.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.textSecondary.withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 60), // Visual balance
        ],
      ),
    );
  }
}
