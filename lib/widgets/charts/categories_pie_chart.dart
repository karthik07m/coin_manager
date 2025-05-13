
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/category_amount.dart';

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
    sortedCategories.sort((a, b) =>
        (b.amount / widget.totalExpenses).compareTo(a.amount / widget.totalExpenses));
  }

  void showTransactionList(
      BuildContext context, int categoryId, String categoryName) {
    // Implement this if needed
  }

  List<PieChartSectionData> buildPieChartSections() {
    return sortedCategories.asMap().entries.map((entry) {
      int index = entry.key;
      CategoryAmount category = entry.value;

      final double percentage = widget.totalExpenses > 0
          ? (category.amount / widget.totalExpenses).clamp(0.0, 1.0)
          : 0.0;

      double radius = _touchedIndex == index ? 50 : 40;

      return PieChartSectionData(
        color: Colors.primaries[index % Colors.primaries.length],
        value: percentage * 100,
        radius: radius,
        showTitle: true,
        title: '${(percentage * 100).toStringAsFixed(1)}%',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
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
            backgroundColor:
                Colors.primaries[index % Colors.primaries.length].withOpacity(0.2),
            child: Image.asset(
              category.icon,
              width: 24,
              height: 24,
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

    return Column(
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
                        if (event is FlTapUpEvent && pieTouchResponse != null) {
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
                  swapAnimationDuration: const Duration(milliseconds: 300),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCategoryName ?? 'Total',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '\$${(_selectedCategoryAmount ?? widget.totalExpenses).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          itemCount: visibleCategories.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final category = visibleCategories[index];
            final percentage = widget.totalExpenses > 0
                ? (category.amount / widget.totalExpenses) * 100
                : 0.0;
            final bgColor = Colors.primaries[index % Colors.primaries.length];

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: bgColor.withOpacity(0.2),
                child: Image.asset(
                  category.icon,
                  width: 24,
                  height: 24,
                ),
              ),
              title: Text(
                category.name,
                style: const TextStyle(fontSize: 14),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${category.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              onTap: () {
                setState(() {
                  _touchedIndex = index;
                  _selectedCategoryName = category.name;
                  _selectedCategoryAmount = category.amount;
                });
                showTransactionList(context, category.id, category.name);
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
              size: 28,
            ),
          ),
      ],
    );
  }
}
