import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // Center "Total" reflects every SELECTED category (not just the top 6
    // drawn), so unchecking a category always subtracts its amount.
    final selectedTotal = sortedCategories
        .where((cat) => _selectedCategories.contains(cat.name))
        .fold(0.0, (sum, cat) => sum + cat.amount);

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
                  UtilityFunction.addCommaWithSign(selectedTotal),
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
                  height: 300,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          PieChart(
                            PieChartData(
                              sections: _buildPieChartSections(
                                  displayCategories, sortedCategories),
                              sectionsSpace:
                                  2, // Small gap for professional look
                              centerSpaceRadius: _centerSpaceRadius, // Donut
                              borderData: FlBorderData(show: false),
                              startDegreeOffset: 270, // Start from top
                              pieTouchData: PieTouchData(
                                touchCallback: (event, pieTouchResponse) {
                                  final index = pieTouchResponse
                                      ?.touchedSection?.touchedSectionIndex;
                                  final validIndex = index != null &&
                                      index >= 0 &&
                                      index < displayCategories.length;

                                  // Release over a slice → open that category.
                                  if (event is FlTapUpEvent) {
                                    if (validIndex) {
                                      HapticFeedback.selectionClick();
                                      _openTransactions(
                                          displayCategories[index].id);
                                    }
                                    setState(() => _touchedIndex = null);
                                    return;
                                  }

                                  // Press / drag → highlight the slice.
                                  final isEnd = event is FlPanEndEvent ||
                                      event is FlLongPressEnd;
                                  setState(() {
                                    _touchedIndex =
                                        isEnd ? null : (validIndex ? index : null);
                                  });
                                },
                              ),
                            ),
                            duration: isAnimating
                                ? Duration.zero
                                : _selectionAnimationDuration,
                            curve: _selectionAnimationCurve,
                          ),
                          // Center display: total, or the selected slice's
                          // name / amount / share. Tappable to open the list.
                          Center(
                            child: Builder(
                              builder: (context) {
                                final bool hasTouched = _touchedIndex != null &&
                                    _touchedIndex! >= 0 &&
                                    _touchedIndex! < displayCategories.length;
                                final CategoryAmount? sel = hasTouched
                                    ? displayCategories[_touchedIndex!]
                                    : null;
                                final double selPct =
                                    (sel != null && filteredTotal > 0)
                                        ? sel.amount / filteredTotal * 100
                                        : 0.0;
                                final int selColorIndex = hasTouched
                                    ? sortedCategories
                                        .indexWhere((c) => c.name == sel!.name)
                                    : -1;
                                final Color selColor = hasTouched
                                    ? _getColor(selColorIndex != -1
                                        ? selColorIndex
                                        : _touchedIndex!)
                                    : context.appAccent;

                                return GestureDetector(
                                  onTap: () => _openTransactions(sel?.id),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        sel?.name ?? 'Total',
                                        style:
                                            AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          letterSpacing: 0.2,
                                          color: hasTouched
                                              ? selColor
                                              : context.textSecondary,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        UtilityFunction.addCommaWithSign(
                                            sel?.amount ?? selectedTotal),
                                        style: AppTextStyles.h2.copyWith(
                                          color: hasTouched
                                              ? selColor
                                              : context.appAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      // Selected → its share of spending;
                                      // otherwise a "tap to view" hint.
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (hasTouched
                                                  ? selColor
                                                  : context.appAccent)
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: hasTouched
                                            ? Text(
                                                '${selPct.toStringAsFixed(selPct < 10 ? 1 : 0)}% of spending',
                                                style: AppTextStyles.bodySmall
                                                    .copyWith(
                                                  color: selColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11,
                                                ),
                                              )
                                            : Row(
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
                                                    style: AppTextStyles
                                                        .bodySmall
                                                        .copyWith(
                                                      color: context.appAccent,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
                    // Amount + share of spending
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        const SizedBox(height: 2),
                        Text(
                          '${percentage < 10 ? percentage.toStringAsFixed(1) : percentage.round()}%',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: (isSelected ? color : context.textSecondary)
                                .withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
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
  // Donut geometry (must match PieChartData below).
  static const double _centerSpaceRadius = 74;
  static const double _sectionRadius = 50;
  static const double _sectionRadiusTouched = 58;

  void _openTransactions(int? categoryId) {
    final startDate =
        DateTime(widget.currentMonth.year, widget.currentMonth.month, 1);
    final endDate =
        DateTime(widget.currentMonth.year, widget.currentMonth.month + 1, 0);

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AllTransactionsScreen(
          initialStartDate: startDate,
          initialEndDate: endDate,
          initialCategoryId: categoryId,
          hideFiltersInitially: true,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slideCurve = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
          );
          final fadeCurve = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
          );
          final scaleCurve = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.15, 0.0),
              end: Offset.zero,
            ).animate(slideCurve),
            child: FadeTransition(
              opacity: fadeCurve,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(scaleCurve),
                child: child,
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _touchedIndex = null);
      }
    });
  }

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
          radius: _sectionRadius,
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
      final radius = isTouched ? _sectionRadiusTouched : _sectionRadius; // Larger touch feedback
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
        // Percentage sits inside the slice; label slices down to 3%.
        showTitle: percentage >= 3,
        title: percentage < 10
            ? '${percentage.round()}%'
            : '${percentage.toStringAsFixed(1)}%',
        titlePositionPercentageOffset: 0.5,
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
        // Category icon floats just outside the ring for major slices, and
        // enlarges on touch. Offset 1.35 keeps it clear of the in-slice %.
        badgeWidget: (isTouched || (anim >= 0.99 && percentage.round() >= 6))
            ? _buildBadge(cat.icon, color, large: isTouched)
            : null,
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
        radius: _sectionRadius,
        showTitle: false,
      ));
    } else if (anim <= 0.0) {
      return [
        PieChartSectionData(
          color: Colors.transparent,
          value: 100,
          radius: _sectionRadius,
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

