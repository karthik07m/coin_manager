import 'package:flutter/material.dart';
import '../utilities/constants.dart';

class CustomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const CustomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        color: colorScheme.surface.withAlpha(230), // Slightly transparent
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: AppShadows.floating,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing8,
            vertical: AppDimensions.spacing8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(
                  context, 0, Icons.home_outlined, Icons.home, 'Home'),
              _buildNavItem(context, 1, Icons.receipt_long_outlined,
                  Icons.receipt_long, 'Transactions'),
              _buildNavItem(context, 2, Icons.calendar_month_outlined,
                  Icons.calendar_month, 'Monthly'),
              _buildNavItem(context, 3, Icons.settings_outlined, Icons.settings,
                  'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData outlinedIcon,
      IconData filledIcon, String label) {
    final isSelected = selectedIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => onItemSelected(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing12,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? filledIcon : outlinedIcon,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.6),
              size: AppDimensions.iconMedium,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
