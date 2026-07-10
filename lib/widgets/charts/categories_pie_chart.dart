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
  final int resetSelectionToken;

  const CategoriesPieChart({
    super.key,
    required this.screenHeight,
    required this.categories,
    required this.totalExpenses,
    required this.currentMonth,
    this.resetSelectionToken = 0,
  });

  @override
  CategoriesPieChartState createState() => CategoriesPieChartState();
}

class CategoriesPieChartState extends State<CategoriesPieChart>
    with SingleTickerProviderStateMixin {
  static const Duration _selectionAnimationDuration =
      Duration(milliseconds: 260);
  static const Curve _selectionAnimationCurve = Curves.easeOutCubic;

  int? _touchedIndex;
  Set<String> _selectedCategories = {};
  bool _hasUserChangedSelection = false;

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

  @override
  void didUpdateWidget(covariant CategoriesPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetSelectionToken != widget.resetSelectionToken ||
        oldWidget.currentMonth != widget.currentMonth) {
      _selectAllCategories();
      return;
    }
    _selectAllCategoriesIfNeeded();
  }

  void _selectAllCategories() {
    _selectedCategories = widget.categories.map((c) => c.name).toSet();
    _hasUserChangedSelection = false;
    _touchedIndex = null;
  }

  void _selectAllCategoriesIfNeeded() {
    if (_hasUserChangedSelection || widget.categories.isEmpty) return;
    _selectAllCategories();
  }

  void _toggleCategory(String name, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedCategories.remove(name);
      } else {
        _selectedCategories.add(name);
      }
      _hasUserChangedSelection = true;
      _touchedIndex = null;
    });
  }

  void _setCategorySelected(String name, bool selected) {
    setState(() {
      if (selected) {
        _selectedCategories.add(name);
      } else {
        _selectedCategories.remove(name);
      }
      _hasUserChangedSelection = true;
      _touchedIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    _selectAllCategoriesIfNeeded();

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
                  color: context.appAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.appAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  UtilityFunction.addCommaWithSign(widget.totalExpenses),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.appAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 24),

        AnimatedSwitcher(
          duration: _selectionAnimationDuration,
          switchInCurve: _selectionAnimationCurve,
          switchOutCurve: Curves.easeInCubic,
          child: hasSelection
              ? SizedBox(
                  key: const ValueKey('category-chart'),
                  height: 320,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Stack(
                        children: [
                          PieChart(
                            PieChartData(
                              sections: _buildPieChartSections(
                                  displayCategories, sortedCategories),
                              sectionsSpace:
                                  2, // Small gap for professional look
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
                                : _selectionAnimationDuration,
                            curve: _selectionAnimationCurve,
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
                                        _touchedIndex! <
                                            displayCategories.length
                                    ? displayCategories[_touchedIndex!].id
                                    : null;

                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation,
                                            secondaryAnimation) =>
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
                                            scale: Tween<double>(
                                                    begin: 0.95, end: 1.0)
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
                                            _touchedIndex! <
                                                displayCategories.length
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
                                            _touchedIndex! <
                                                displayCategories.length
                                        ? UtilityFunction.addCommaWithSign(
                                            displayCategories[_touchedIndex!]
                                                .amount)
                                        : UtilityFunction.addCommaWithSign(widget
                                            .totalExpenses), // Use the total from parent for accuracy
                                    style: AppTextStyles.h2.copyWith(
                                      color: context.appAccent,
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
                                      color: context.appAccent
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.touch_app,
                                          size: 14,
                                          color: context.appAccent,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'View Details',
                                          style:
                                              AppTextStyles.bodySmall.copyWith(
                                            color: context.appAccent,
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
              : _buildEmptyState(context),
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
                _toggleCategory(category.name, isSelected);
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: _selectionAnimationDuration,
                curve: _selectionAnimationCurve,
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
                          _setCategorySelected(
                            category.name,
                            value == true,
                          );
                        },
                        activeColor: color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Icon
                    AnimatedContainer(
                      duration: _selectionAnimationDuration,
                      curve: _selectionAnimationCurve,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : AppColors.divider.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: AnimatedOpacity(
                        duration: _selectionAnimationDuration,
                        curve: _selectionAnimationCurve,
                        opacity: isSelected ? 1 : 0.45,
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
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0,
                              end: isSelected ? percentage / 100 : 0,
                            ),
                            duration: _selectionAnimationDuration,
                            curve: _selectionAnimationCurve,
                            builder: (context, value, child) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: value,
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
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Amount
                    AnimatedDefaultTextStyle(
                      duration: _selectionAnimationDuration,
                      curve: _selectionAnimationCurve,
                      style: AppTextStyles.h3.copyWith(
                        color: isSelected ? color : context.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      child: Text(
                        UtilityFunction.addCommaWithSign(category.amount),
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

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      key: const ValueKey('category-chart-empty'),
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
        // Label slices down to 3%; tinier ones stay in the legend below.
        showTitle: percentage >= 3,
        // Whole % under 10 keeps the label compact on a thin slice.
        title: percentage < 10
            ? '${percentage.round()}%'
            : '${percentage.toStringAsFixed(1)}%',
        titleStyle: AppTextStyles.bodySmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: isTouched ? 16 : 13, // Larger text when touched
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
        // Float icons on the ring once the entrance sweep finishes; always
        // show the touched one (enlarged). ≥6% avoids crowding thin slices.
        // Badge major slices only. Use the *rounded* percentage so a slice
        // that displays "6%" (e.g. 5.9%) also gets its icon — thin 3%-ish
        // slices cluster too tightly for floating icons and stay in the
        // legend below.
        badgeWidget: (isTouched || (anim >= 0.99 && percentage.round() >= 6))
            ? _buildBadge(cat.icon, color, large: isTouched)
            : null,
        // Sit the badge just outside the ring so it never overlaps the
        // in-slice percentage label.
        badgePositionPercentageOffset: 1.35,
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

  /// Circular category icon that floats on the donut ring, ringed and
  /// glowing in the slice's colour so it reads as belonging to that wedge.
  Widget _buildBadge(String iconPath, Color color, {bool large = false}) {
    final double size = large ? 40 : 32;
    final double iconSize = large ? 20 : 16;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: size,
      height: size,
      padding: EdgeInsets.all(large ? 8 : 6),
      decoration: BoxDecoration(
        color: context.appSurface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: large ? 12 : 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Image.asset(
        iconPath,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.category, size: iconSize, color: color),
      ),
    );
  }

  Color _getColor(int index) {
    final colors = [
      AppColors.positive, // fixed palette green, not the user accent
      AppColors.accentBlue,
      AppColors.warning,
      AppColors.accentPurple,
      AppColors.negative,
      AppColors.secondary,
    ];
    return colors[index % colors.length];
  }
}
