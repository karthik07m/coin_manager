import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/category_amount.dart';
import '../../utilities/constants.dart';

class CategoriesPieChart extends StatefulWidget {
  final double screenHeight;
  final List<CategoryAmount> categories;
  final double totalExpenses;

  const CategoriesPieChart({
    super.key,
    required this.screenHeight,
    required this.categories,
    required this.totalExpenses,
  });

  @override
  CategoriesPieChartState createState() => CategoriesPieChartState();
}

class CategoriesPieChartState extends State<CategoriesPieChart> {
  int? _touchedIndex;
  String? _selectedCategoryName;
  double? _selectedCategoryAmount;

  late List<CategoryAmount> sortedCategories;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    sortCategories();
  }

  void sortCategories() {
    sortedCategories = [...widget.categories];
    sortedCategories.sort((a, b) => (b.amount / widget.totalExpenses)
        .compareTo(a.amount / widget.totalExpenses));
  }

  void showTransactionList(
      BuildContext context, int categoryId, String categoryName) {
    // Implement this if needed
  }

  List<PieChartSectionData> buildPieChartSections() {
    if (sortedCategories.isEmpty) {
      return [
        PieChartSectionData(
          color: Theme.of(context).colorScheme.surface,
          value: 100,
          radius: 40,
          showTitle: false,
        )
      ];
    }

    return sortedCategories.asMap().entries.map((entry) {
      int index = entry.key;
      CategoryAmount category = entry.value;

      final double percentage = widget.totalExpenses > 0
          ? (category.amount / widget.totalExpenses).clamp(0.0, 1.0)
          : 0.0;

      if (percentage.isNaN || percentage <= 0) {
        return PieChartSectionData(
          color: Colors.grey.withValues(alpha: 0.1),
          value: 0,
          radius: 40,
          showTitle: false,
        );
      }

      double radius = _touchedIndex == index ? 50 : 40;

      return PieChartSectionData(
        color: Colors.primaries[index % Colors.primaries.length]
            .withValues(alpha: 0.8),
        value: percentage * 100,
        radius: radius,
        showTitle: true,
        title: '${(percentage * 100).toStringAsFixed(1)}%',
        titleStyle: AppTextStyles.caption.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        badgeWidget: GestureDetector(
          onTap: () {
            setState(() {
              _touchedIndex = index;
              _selectedCategoryName = category.name;
              _selectedCategoryAmount = category.amount;
            });
          },
          child: CircleAvatar(
            backgroundColor: Colors.primaries[index % Colors.primaries.length]
                .withValues(alpha: 0.2),
            child: Image.asset(
              category.icon,
              width: AppDimensions.iconMedium,
              height: AppDimensions.iconMedium,
            ),
          ),
        ),
        badgePositionPercentageOffset: 1.4,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    sortCategories();

    final visibleCategories =
        _showAll ? sortedCategories : sortedCategories.take(4).toList();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: AppDimensions.elevationMedium,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Column(
          children: [
            SizedBox(
              height: widget.screenHeight * 0.5,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: PieChart(
                      PieChartData(
                        sections: buildPieChartSections(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 80,
                        borderData: FlBorderData(show: false),
                        startDegreeOffset: -90,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, pieTouchResponse) {
                            if (event is FlTapUpEvent &&
                                pieTouchResponse != null) {
                              final touchedIndex = pieTouchResponse
                                  .touchedSection?.touchedSectionIndex;
                              if (touchedIndex != null && touchedIndex >= 0) {
                                setState(() {
                                  _touchedIndex = touchedIndex;
                                  final category =
                                      sortedCategories[_touchedIndex!];
                                  _selectedCategoryName = category.name;
                                  _selectedCategoryAmount = category.amount;
                                });
                              } else {
                                setState(() {
                                  _touchedIndex = null;
                                  _selectedCategoryName = null;
                                  _selectedCategoryAmount = null;
                                });
                              }
                            }
                          },
                        ),
                      ),
                      duration: AppDurations.medium,
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedCategoryName ?? 'Total',
                          style: textTheme.displaySmall?.copyWith(
                              fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: AppDimensions.spacing4),
                        Text(
                          '\$${(_selectedCategoryAmount ?? widget.totalExpenses).toStringAsFixed(2)}',
                          style: AppTextStyles.amount.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppDimensions.spacing16),
            ListView.builder(
              itemCount: visibleCategories.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final category = visibleCategories[index];
                final percentage = widget.totalExpenses > 0
                    ? (category.amount / widget.totalExpenses) * 100
                    : 0.0;
                final bgColor =
                    Colors.primaries[index % Colors.primaries.length];

                return ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing8,
                    vertical: AppDimensions.spacing4,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: bgColor.withValues(alpha: 0.2),
                    child: Image.asset(
                      category.icon,
                      width: AppDimensions.iconMedium,
                      height: AppDimensions.iconMedium,
                    ),
                  ),
                  title: Text(
                    category.name,
                    style: textTheme.bodyMedium,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${category.amount.toStringAsFixed(2)}',
                        style: AppTextStyles.amount
                            .copyWith(color: colorScheme.onSurface),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: AppTextStyles.caption.copyWith(
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      _touchedIndex = index;
                      _selectedCategoryName = category.name;
                      _selectedCategoryAmount = category.amount;
                    });
                  },
                );
              },
            ),
            if (sortedCategories.length > 4)
              IconButton(
                onPressed: () {
                  setState(() {
                    _showAll = !_showAll;
                  });
                },
                icon: Icon(
                  _showAll
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: AppDimensions.iconMedium,
                  color: colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
