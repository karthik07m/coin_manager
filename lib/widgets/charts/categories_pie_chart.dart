import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/category_amount.dart';
import '../../utilities/constants.dart';
import '../../utilities/theme_helper.dart';
import '../../utilities/functions.dart';
import '../../screens/all_transactions_screen.dart';

class CategoriesPieChart extends StatefulWidget {
  final double screenHeight;
  final List<CategoryAmount> categories;
  final double totalExpenses;
  final DateTime currentMonth;

  const CategoriesPieChart({
    super.key,
    required this.screenHeight,
    required this.categories,
    required this.totalExpenses,
    required this.currentMonth,
  });

  @override
  CategoriesPieChartState createState() => CategoriesPieChartState();
}

class CategoriesPieChartState extends State<CategoriesPieChart>
    with SingleTickerProviderStateMixin {
  int? _touchedIndex;
  Set<String> _selectedCategories = {};

  // Animation controller for entrance animation
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Slower, premium feel
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart, // Very smooth deceleration
    );

    // Initialize selected categories once
    _initializeSelectedCategories();

    // Start animation after a small delay to allow UI to settle
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeSelectedCategories() {
    // Select all categories by default
    _selectedCategories = widget.categories.map((c) => c.name).toSet();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Sort all categories by amount descending
    final sortedCategories = List<CategoryAmount>.from(widget.categories)
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // 2. Filter for chart based on sorted list
    final displayCategories = sortedCategories
        .where((cat) => _selectedCategories.contains(cat.name))
        .take(6)
        .toList();

    final filteredTotal =
        displayCategories.fold(0.0, (sum, cat) => sum + cat.amount);

    final hasSelection = displayCategories.isNotEmpty;
    // Don't use swap animation during the entrance sweep to avoid lag
    // Use it only for touch interactions after entrance is done
    final isAnimating = _animationController.isAnimating;

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
            if (hasSelection)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  UtilityFunction.addCommaWithSign(widget.totalExpenses),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 24),

        // Pie Chart or Empty State
        if (hasSelection)
          SizedBox(
            height: 260,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        sections: _buildPieChartSections(
                            displayCategories, sortedCategories),
                        sectionsSpace: 2, // Small gap for professional look
                        centerSpaceRadius: 75, // Donut style
                        borderData: FlBorderData(show: false),
                        startDegreeOffset: 270, // Start from top
                        pieTouchData: PieTouchData(
                          touchCallback: (event, pieTouchResponse) {
                            if (event is FlTapUpEvent &&
                                pieTouchResponse != null) {
                              final index = pieTouchResponse
                                  .touchedSection?.touchedSectionIndex;

                              if (index != null &&
                                  index >= 0 &&
                                  index < displayCategories.length) {
                                // Only provide visual feedback, no navigation
                                setState(() {
                                  _touchedIndex = index;
                                });
                              }
                            } else if (event is FlPanEndEvent ||
                                event is FlTapUpEvent) {
                              // Reset touched state when user stops touching
                              setState(() {
                                _touchedIndex = null;
                              });
                            }
                          },
                        ),
                      ),
                      duration: isAnimating
                          ? Duration.zero
                          : const Duration(milliseconds: 150),
                      curve: Curves.linear,
                    ),
                    // Center display (Total or Selected) - Tappable for all transactions
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          final startDate = DateTime(
                            widget.currentMonth.year,
                            widget.currentMonth.month,
                            1,
                          );
                          final endDate = DateTime(
                            widget.currentMonth.year,
                            widget.currentMonth.month + 1,
                            0,
                          );

                          // Determine if we should filter by category
                          final int? categoryId = _touchedIndex != null &&
                                  _touchedIndex! >= 0 &&
                                  _touchedIndex! < displayCategories.length
                              ? displayCategories[_touchedIndex!].id
                              : null;

                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      AllTransactionsScreen(
                                initialStartDate: startDate,
                                initialEndDate: endDate,
                                initialCategoryId:
                                    categoryId, // Filter by category if touched
                                hideFiltersInitially: true,
                              ),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                // Same premium animation for consistency
                                const slideBegin = Offset(0.15, 0.0);
                                const slideEnd = Offset.zero;

                                final slideCurve = CurvedAnimation(
                                  parent: animation,
                                  curve: const Interval(0.0, 1.0,
                                      curve: Curves.easeOutCubic),
                                );

                                final fadeCurve = CurvedAnimation(
                                  parent: animation,
                                  curve: const Interval(0.0, 0.5,
                                      curve: Curves.easeIn),
                                );

                                final scaleCurve = CurvedAnimation(
                                  parent: animation,
                                  curve: const Interval(0.0, 0.8,
                                      curve: Curves.easeOutBack),
                                );

                                return SlideTransition(
                                  position: Tween<Offset>(
                                    begin: slideBegin,
                                    end: slideEnd,
                                  ).animate(slideCurve),
                                  child: FadeTransition(
                                    opacity: fadeCurve,
                                    child: ScaleTransition(
                                      scale:
                                          Tween<double>(begin: 0.95, end: 1.0)
                                              .animate(scaleCurve),
                                      child: child,
                                    ),
                                  ),
                                );
                              },
                              transitionDuration:
                                  const Duration(milliseconds: 500),
                            ),
                          ).then((_) {
                            // Reset touched state when returning
                            if (mounted) {
                              setState(() {
                                _touchedIndex = null;
                              });
                            }
                          });
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _touchedIndex != null &&
                                      _touchedIndex! >= 0 &&
                                      _touchedIndex! < displayCategories.length
                                  ? displayCategories[_touchedIndex!].name
                                  : 'Total',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                letterSpacing: 0.2,
                                color: context.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _touchedIndex != null &&
                                      _touchedIndex! >= 0 &&
                                      _touchedIndex! < displayCategories.length
                                  ? UtilityFunction.addCommaWithSign(
                                      displayCategories[_touchedIndex!].amount)
                                  : UtilityFunction.addCommaWithSign(widget
                                      .totalExpenses), // Use the total from parent for accuracy
                              style: AppTextStyles.h2.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 26,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // View Details hint
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'View Details',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          )
        else
          Container(
            height: 260,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.appSurfaceLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.pie_chart_outline,
                  size: 48,
                  color: context.textSecondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'No Categories Selected',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select categories below to view chart',
                  style: AppTextStyles.caption.copyWith(
                    color: context.textSecondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 28),

        // Categories List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedCategories.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final category = sortedCategories[index];
            final percentage = filteredTotal > 0
                ? (category.amount / filteredTotal * 100)
                : 0.0;
            final isSelected = _selectedCategories.contains(category.name);
            final color = _getColor(
                index); // Use sorted index for consistent rank-based color

            return InkWell(
              onTap: () {
                setState(() {
                  // This toggles filter inclusion
                  if (isSelected) {
                    _selectedCategories.remove(category.name);
                  } else {
                    _selectedCategories.add(category.name);
                  }
                  _touchedIndex = null;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.appBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? color.withValues(alpha: 0.3)
                        : AppColors.divider.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Checkbox
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedCategories.add(category.name);
                            } else {
                              _selectedCategories.remove(category.name);
                            }
                            _touchedIndex = null;
                          });
                        },
                        activeColor: color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : AppColors.divider.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Image.asset(
                        category.icon,
                        width: 20,
                        height: 20,
                        colorBlendMode:
                            isSelected ? null : BlendMode.saturation,
                        color: isSelected
                            ? null
                            : context.textSecondary.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Category details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isSelected ? null : context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor:
                                  AppColors.divider.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isSelected
                                    ? color
                                    : context.textSecondary
                                        .withValues(alpha: 0.3),
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Amount
                    Text(
                      UtilityFunction.addCommaWithSign(category.amount),
                      style: AppTextStyles.h3.copyWith(
                        color: isSelected ? color : context.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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

  // Uses a Dummy Section to simulate "Sweeping" animation
  List<PieChartSectionData> _buildPieChartSections(
      List<CategoryAmount> categories,
      List<CategoryAmount> allSortedCategories) {
    // 1. Calculate total for visible slices
    final totalVisible = categories.fold(0.0, (sum, cat) => sum + cat.amount);

    if (totalVisible <= 0) {
      return [
        PieChartSectionData(
          color: Colors.transparent,
          value: 100,
          radius: 45,
          showTitle: false,
        ),
      ];
    }

    final sections = <PieChartSectionData>[];
    final anim = _animation.value;

    // 2. Add real visible sections
    // They maintain relative proportions but scale with animation
    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      final isTouched = _touchedIndex == i;
      final radius = isTouched ? 60.0 : 50.0; // Larger touch feedback
      final percentage =
          totalVisible > 0 ? (cat.amount / totalVisible * 100) : 0.0;

      // Find the consistent color based on rank in the full list
      final colorIndex =
          allSortedCategories.indexWhere((c) => c.name == cat.name);
      final color = _getColor(colorIndex != -1 ? colorIndex : i);

      sections.add(PieChartSectionData(
        color: color,
        value: cat.amount,
        radius: radius,
        showTitle: percentage > 4, // Only show if > 4% to avoid clutter
        title: '${percentage.toStringAsFixed(1)}%', // Show one decimal place
        titleStyle: AppTextStyles.bodySmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: isTouched ? 15 : 12, // Larger text when touched
          shadows: isTouched
              ? [
                  const Shadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  )
                ]
              : null,
        ),
        badgeWidget: _touchedIndex == i ? _buildBadge(cat.icon) : null,
        badgePositionPercentageOffset: .98,
      ));
    }

    // 3. Add Dummy section
    // As anim goes 0->1, dummy goes 100%->0% of chart
    if (anim < 1.0 && anim > 0.0) {
      final dummyVal = totalVisible * (1.0 - anim) / anim;
      sections.add(PieChartSectionData(
        color: Colors.transparent,
        value: dummyVal,
        radius: 48,
        showTitle: false,
      ));
    } else if (anim <= 0.0) {
      return [
        PieChartSectionData(
          color: Colors.transparent,
          value: 100,
          radius: 50,
          showTitle: false,
        ),
      ];
    }

    return sections;
  }

  Widget _buildBadge(String iconPath) {
    return Container(
      decoration: BoxDecoration(
        color: context.appBackground,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Image.asset(
        iconPath,
        width: 16,
        height: 16,
        fit: BoxFit.contain,
      ),
    );
  }

  Color _getColor(int index) {
    final colors = [
      AppColors.primary,
      AppColors.accentBlue,
      AppColors.warning,
      AppColors.accentPurple,
      AppColors.negative,
      AppColors.secondary,
    ];
    return colors[index % colors.length];
  }
}
