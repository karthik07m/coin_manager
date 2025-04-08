import 'dart:math' as math;
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
    // Implement this
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
        showTitle: false,
      );
    }).toList();
  }

  List<Widget> buildExternalLabels() {
    final List<Widget> labelWidgets = [];
    final double chartRadius = widget.screenHeight * 0.15;
    final double centerX = widget.screenHeight * 0.25;
    final double centerY = widget.screenHeight * 0.25;
    double startAngle = -90.0;

    for (int i = 0; i < sortedCategories.length; i++) {
      final category = sortedCategories[i];
      final double sweepAngle = widget.totalExpenses > 0
          ? (category.amount / widget.totalExpenses) * 360
          : 0.0;
      final double midAngle = startAngle + sweepAngle / 2;
      final double radians = midAngle * (math.pi / 180);

      final double lineStartX =
          centerX + (chartRadius + 10) * math.cos(radians);
      final double lineStartY =
          centerY + (chartRadius + 10) * math.sin(radians);
      final double lineEndX =
          centerX + (chartRadius + 40) * math.cos(radians);
      final double lineEndY =
          centerY + (chartRadius + 40) * math.sin(radians);

      labelWidgets.add(CustomPaint(
        painter: LinePainter(
          startX: lineStartX,
          startY: lineStartY,
          endX: lineEndX,
          endY: lineEndY,
          color: Colors.primaries[i % Colors.primaries.length],
        ),
      ));

      labelWidgets.add(Positioned(
        left: lineEndX - 10,
        top: lineEndY - 10,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedCategoryName = category.name;
              _selectedCategoryAmount = category.amount;
              _touchedIndex = i;
            });
            showTransactionList(context, category.id, category.name);
          },
          child: Image.asset(
            category.icon,
            width: 20,
            height: 20,
          ),
        ),
      ));

      startAngle += sweepAngle;
    }

    return labelWidgets;
  }

  @override
  Widget build(BuildContext context) {
    sortCategories(); // Re-sort every build in case data updates

    return Column(
      children: [
        // PIE CHART SECTION
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
                    centerSpaceRadius: 60,
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
                              final category = sortedCategories[_touchedIndex!];
                              _selectedCategoryName = category.name;
                              _selectedCategoryAmount = category.amount;
                            });
                          } else {
                            setState(() {
                              _touchedIndex = null;
                            });
                          }
                        }
                      },
                    ),
                  ),
                  swapAnimationDuration: Duration(milliseconds: 300),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: _selectedCategoryName != null &&
                        _selectedCategoryAmount != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedCategoryName!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '\$${_selectedCategoryAmount!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      )
                    : Container(),
              ),
              ...buildExternalLabels(),
            ],
          ),
        ),

        // SORTED CATEGORY LIST
        const SizedBox(height: 12),
        ListView.builder(
          itemCount: sortedCategories.length,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final category = sortedCategories[index];
            final percentage = widget.totalExpenses > 0
                ? (category.amount / widget.totalExpenses) * 100
                : 0.0;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.white,
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
              trailing: Text(
                '${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
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
      ],
    );
  }
}

class LinePainter extends CustomPainter {
  final double startX, startY, endX, endY;
  final Color color;

  LinePainter({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
