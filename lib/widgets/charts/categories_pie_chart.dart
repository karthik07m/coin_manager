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

  @override
  Widget build(BuildContext context) {
    // Sort categories by amount
    final sortedCategories = [...widget.categories];
    sortedCategories.sort((a, b) => b.amount.compareTo(a.amount));

    // Take top 6 categories
    final topCategories = sortedCategories.take(6).toList();

    if (topCategories.isEmpty || widget.totalExpenses == 0) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Spending Breakdown',
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '\$${widget.totalExpenses.toStringAsFixed(2)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Pie Chart
        SizedBox(
          height: 220,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  sections: _buildPieChartSections(topCategories),
                  sectionsSpace: 3,
                  centerSpaceRadius: 70,
                  borderData: FlBorderData(show: false),
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, pieTouchResponse) {
                      if (event is FlTapUpEvent && pieTouchResponse != null) {
                        setState(() {
                          final index = pieTouchResponse
                              .touchedSection?.touchedSectionIndex;
                          // Validate index is within bounds
                          if (index != null &&
                              index >= 0 &&
                              index < topCategories.length) {
                            _touchedIndex = index;
                          } else {
                            _touchedIndex = null;
                          }
                        });
                      }
                    },
                  ),
                ),
              ),
              // Center text
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _touchedIndex != null &&
                              _touchedIndex! >= 0 &&
                              _touchedIndex! < topCategories.length
                          ? topCategories[_touchedIndex!].name
                          : 'Total',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _touchedIndex != null &&
                              _touchedIndex! >= 0 &&
                              _touchedIndex! < topCategories.length
                          ? '\$${topCategories[_touchedIndex!].amount.toStringAsFixed(2)}'
                          : '\$${widget.totalExpenses.toStringAsFixed(2)}',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    if (_touchedIndex != null &&
                        _touchedIndex! >= 0 &&
                        _touchedIndex! < topCategories.length)
                      Text(
                        '${((topCategories[_touchedIndex!].amount / widget.totalExpenses) * 100).toStringAsFixed(1)}%',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Legend - Grid layout
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: topCategories.length,
          itemBuilder: (context, index) {
            final category = topCategories[index];
            final percentage = (category.amount / widget.totalExpenses * 100);
            final color = _getColor(index);

            return InkWell(
              onTap: () {
                setState(() {
                  _touchedIndex = index;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _touchedIndex == index
                      ? color.withValues(alpha: 0.15)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _touchedIndex == index ? color : AppColors.divider,
                    width: _touchedIndex == index ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Color dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Icon
                    Image.asset(
                      category.icon,
                      width: 16,
                      height: 16,
                    ),
                    const SizedBox(width: 4),
                    // Name and percentage
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            category.name,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${percentage.toStringAsFixed(1)}% • \$${category.amount.toStringAsFixed(0)}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
      List<CategoryAmount> categories) {
    return categories.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;
      final percentage = (category.amount / widget.totalExpenses * 100);
      final isTouched = _touchedIndex == index;
      final radius = isTouched ? 50.0 : 45.0;
      final color = _getColor(index);

      return PieChartSectionData(
        color: color,
        value: percentage,
        radius: radius,
        showTitle: false,
      );
    }).toList();
  }

  Color _getColor(int index) {
    final colors = [
      AppColors.primary, // Vibrant Emerald Green
      AppColors.accentBlue, // Bright Blue
      AppColors.warning, // Orange
      AppColors.accentPurple, // Amethyst Purple
      AppColors.negative, // Bright Red
      AppColors.secondary, // Electric Gold
    ];
    return colors[index % colors.length];
  }

  Widget _buildEmptyState() {
    return Container(
      height: 250,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No expenses yet',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start adding transactions to see your spending breakdown',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
