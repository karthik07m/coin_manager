import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

class CustomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const CustomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  static const _destinations = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'List'),
    (
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
      'Budget'
    ),
    (Icons.pie_chart_outline, Icons.pie_chart, 'Charts'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'AI'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Material(
        color: context.appSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: context.appBorder.withValues(alpha: 0.7)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(_destinations.length, (index) {
              final (outlined, filled, label) = _destinations[index];
              final selected = index == selectedIndex;
              final accessibleLabel = label == 'List'
                  ? 'Transactions'
                  : label == 'AI'
                      ? 'AI assistant'
                      : label;
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: accessibleLabel,
                  child: Tooltip(
                    message: accessibleLabel,
                    excludeFromSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        if (!selected) HapticFeedback.selectionClick();
                        onItemSelected(index);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : AppDurations.fast,
                              curve: Curves.easeOutCubic,
                              // The pill grows out from the icon, like M3's
                              // navigation indicator.
                              width: selected ? 48 : 28,
                              height: 30,
                              decoration: BoxDecoration(
                                color: selected
                                    ? context.appAccentSurface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(selected ? filled : outlined,
                                  size: 22,
                                  color: selected
                                      ? scheme.primary
                                      : context.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            ExcludeSemantics(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(label,
                                    maxLines: 1,
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        height: 1.2,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: selected
                                            ? context.textPrimary
                                            : context.textSecondary)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
