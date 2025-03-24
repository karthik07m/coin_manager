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

  void showTransactionList(
      BuildContext context, int categoryId, String categoryName) {
    // Your method to show transaction list
  }

  List<PieChartSectionData> buildPieChartSections() {
    return widget.categories.asMap().entries.map((entry) {
      int index = entry.key;
      CategoryAmount category = entry.value;
      final double percentage = widget.totalExpenses > 0
          ? (category.amount / widget.totalExpenses).clamp(0.0, 1.0)
          : 0.0;

      // Expand the selected category
      double radius = _touchedIndex == index
          ? 50
          : 40; // Increased radius for selected category

      return PieChartSectionData(
        color: Colors.primaries[index % Colors.primaries.length],
        value: percentage * 100,
        radius: radius,
        title: '${(percentage * 100).toStringAsFixed(1)}%',
      );
    }).toList();
  }

  List<Widget> buildExternalLabels() {
    final List<Widget> labelWidgets = [];
    final double chartRadius =
        widget.screenHeight * 0.15; // Further reduced radius of the chart
    final double centerX = widget.screenHeight * 0.25; // Center X
    final double centerY = widget.screenHeight * 0.25; // Center Y
    double startAngle = -90.0;

    for (int i = 0; i < widget.categories.length; i++) {
      final category = widget.categories[i];
      final double sweepAngle = widget.totalExpenses > 0
          ? (category.amount / widget.totalExpenses) * 360
          : 0.0;
      final double midAngle = startAngle + sweepAngle / 2;
      final double radians = midAngle * (math.pi / 180);

      // Start position at the outer edge of the pie chart
      final double lineStartX =
          centerX + (chartRadius + 10) * math.cos(radians);
      final double lineStartY =
          centerY + (chartRadius + 10) * math.sin(radians);
      // End position at the icon
      final double lineEndX = centerX + (chartRadius + 40) * math.cos(radians);
      final double lineEndY = centerY + (chartRadius + 40) * math.sin(radians);

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
              _touchedIndex = i; // Set touched index for highlighting
            });
            showTransactionList(context, category.id, category.name);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                category.icon,
                width: 20,
                height: 20,
              ),
            ],
          ),
        ),
      ));

      startAngle += sweepAngle;
    }

    return labelWidgets;
  }

  @override
  Widget build(BuildContext context) {
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
                    centerSpaceRadius: 60,
                    borderData: FlBorderData(show: false),
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        if (event is FlTapUpEvent && pieTouchResponse != null) {
                          final touchedIndex = pieTouchResponse
                              .touchedSection?.touchedSectionIndex;
                          if (touchedIndex != null && touchedIndex >= 0) {
                            setState(() {
                              _touchedIndex = touchedIndex;
                              final category =
                                  widget.categories[_touchedIndex!];
                              _selectedCategoryName = category.name;
                              _selectedCategoryAmount = category.amount;
                            });
                          } else {
                            setState(() {
                              _touchedIndex =
                                  null; // Reset if no valid section was touched
                            });
                          }
                        }
                      },
                    ),
                  ),
                  swapAnimationDuration: Duration.zero,
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            '\$${_selectedCategoryAmount!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      )
                    : Container(), // Empty container if no category is selected
              ),
              ...buildExternalLabels(),
            ],
          ),
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
