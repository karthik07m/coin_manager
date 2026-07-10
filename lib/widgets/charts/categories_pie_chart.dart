import 'dart:math' as math;
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
                  height: 340,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return LayoutBuilder(
                          builder: (context, constraints) {
                        return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Leader-line callouts (name + %) around the ring.
                          if (_animation.value >= 0.99)
                            ..._buildLeaderCallouts(
                              constraints.biggest,
                              displayCategories,
                              sortedCategories,
                            ),
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
                          // Center display (Total or Selected) - Tappable for all transactions
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                // Center opens the currently highlighted
                                // category, or all transactions if none.
                                final int? categoryId = _touchedIndex != null &&
                                        _touchedIndex! >= 0 &&
                                        _touchedIndex! <
                                            displayCategories.length
                                    ? displayCategories[_touchedIndex!].id
                                    : null;
                                _openTransactions(categoryId);
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
                                      fontSize: 12,
                                      letterSpacing: 0.2,
                                      color: context.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
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
                                      fontSize: 17,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
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
                      });
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
  // Donut geometry (must match PieChartData below). Kept compact so the
  // external leader-line labels have room beside it on a phone.
  static const double _centerSpaceRadius = 58;
  static const double _sectionRadius = 32;
  static const double _sectionRadiusTouched = 38;
  static const double _ringOuter = _centerSpaceRadius + _sectionRadius; // 90

  /// External leader-line callouts: for each slice >=4%, a line runs from the
  /// ring out to a floating "Name / % · amount" label — the professional
  /// pie-chart style. Labels are split left/right and spread vertically so
  /// they never overlap. Tiny slices stay in the legend below.
  List<Widget> _buildLeaderCallouts(
    Size size,
    List<CategoryAmount> categories,
    List<CategoryAmount> allSorted,
  ) {
    if (size.width <= 0 || size.height <= 0) return const [];
    final total = categories.fold(0.0, (s, c) => s + c.amount);
    if (total <= 0) return const [];

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Build a callout per qualifying slice.
    final left = <_Callout>[];
    final right = <_Callout>[];
    double cumulative = 0; // degrees swept so far
    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      final pct = cat.amount / total * 100;
      final sweep = cat.amount / total * 360;
      final midDeg = 270 + cumulative + sweep / 2; // 270 = start at top
      cumulative += sweep;
      if (pct < 4) continue;

      final rad = midDeg * math.pi / 180;
      final cos = math.cos(rad);
      final sin = math.sin(rad);
      final anchor = Offset(cx + _ringOuter * cos, cy + _ringOuter * sin);
      final knee = Offset(cx + (_ringOuter + 12) * cos, cy + (_ringOuter + 12) * sin);

      final colorIndex = allSorted.indexWhere((c) => c.name == cat.name);
      final color = _getColor(colorIndex != -1 ? colorIndex : i);

      final callout = _Callout(
        name: cat.name,
        iconPath: cat.icon,
        pct: pct,
        amount: cat.amount,
        color: color,
        anchor: anchor,
        knee: knee,
        targetY: knee.dy,
        onRight: cos >= 0,
      );
      (callout.onRight ? right : left).add(callout);
    }

    // Spread each side vertically so labels don't collide.
    const labelH = 40.0;
    void distribute(List<_Callout> list) {
      list.sort((a, b) => a.targetY.compareTo(b.targetY));
      for (int i = 1; i < list.length; i++) {
        final minY = list[i - 1].y + labelH;
        if (list[i].y < minY) list[i].y = minY;
      }
      // Nudge back up if we ran past the bottom.
      final overflow = list.isNotEmpty ? list.last.y + labelH / 2 - size.height : 0;
      if (overflow > 0) {
        for (final c in list) {
          c.y = (c.y - overflow).clamp(labelH / 2, size.height - labelH / 2);
        }
      }
    }

    for (final c in [...left, ...right]) {
      c.y = c.targetY.clamp(labelH / 2, size.height - labelH / 2);
    }
    distribute(left);
    distribute(right);

    const double labelW = 82;
    final widgets = <Widget>[
      // The lines beneath the labels.
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _LeaderLinePainter(
              callouts: [...left, ...right],
              labelWidth: labelW,
              size: size,
            ),
          ),
        ),
      ),
    ];

    for (final c in [...left, ...right]) {
      widgets.add(Positioned(
        top: c.y - labelH / 2,
        left: c.onRight ? size.width - labelW : 0,
        width: labelW,
        height: labelH,
        child: IgnorePointer(
          child: Column(
            crossAxisAlignment: c.onRight
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon + name on one line (icon leads on whichever side).
              Row(
                mainAxisSize: MainAxisSize.min,
                textDirection:
                    c.onRight ? TextDirection.ltr : TextDirection.rtl,
                children: [
                  Image.asset(
                    c.iconPath,
                    width: 14,
                    height: 14,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.category, size: 14, color: c.color),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      c.name,
                      textAlign: c.onRight ? TextAlign.left : TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                '${c.pct.toStringAsFixed(c.pct < 10 ? 1 : 0)}%',
                textAlign: c.onRight ? TextAlign.left : TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  letterSpacing: 0,
                  color: c.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ));
    }
    return widgets;
  }

  /// Opens the month's transactions, optionally filtered to one category.
  /// Shared by slice taps and the donut center.
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
        // Percentages are rendered as external leader-line callouts (see the
        // overlay in build); the in-slice title stays off to avoid clutter.
        showTitle: false,
        title: '${percentage.round()}%',
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
        // Category icons now live in the external leader-line labels, so the
        // thin band only shows an enlarged icon while a slice is touched.
        badgeWidget:
            isTouched ? _buildBadge(cat.icon, color, large: true) : null,
        badgePositionPercentageOffset: 0.5,
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

/// One external callout: an anchor on the ring, a knee just outside it, and a
/// resolved label y (spread to avoid collisions).
class _Callout {
  final String name;
  final String iconPath;
  final double pct;
  final double amount;
  final Color color;
  final Offset anchor;
  final Offset knee;
  final double targetY;
  final bool onRight;
  double y;

  _Callout({
    required this.name,
    required this.iconPath,
    required this.pct,
    required this.amount,
    required this.color,
    required this.anchor,
    required this.knee,
    required this.targetY,
    required this.onRight,
  }) : y = targetY;
}

/// Draws the leader lines: ring anchor → knee → horizontal run to the label,
/// with a small dot at the anchor, each in its slice colour.
class _LeaderLinePainter extends CustomPainter {
  final List<_Callout> callouts;
  final double labelWidth;
  final Size size;

  _LeaderLinePainter({
    required this.callouts,
    required this.labelWidth,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (final c in callouts) {
      final paint = Paint()
        ..color = c.color.withValues(alpha: 0.8)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Horizontal run ends where the label starts.
      final labelInnerX =
          c.onRight ? canvasSize.width - labelWidth : labelWidth;
      final elbow = Offset(labelInnerX, c.y);

      final path = Path()
        ..moveTo(c.anchor.dx, c.anchor.dy)
        ..lineTo(c.knee.dx, c.knee.dy)
        ..lineTo(elbow.dx, elbow.dy);
      canvas.drawPath(path, paint);

      // Dot at the ring anchor.
      canvas.drawCircle(
        c.anchor,
        2.5,
        Paint()..color = c.color,
      );
    }
  }

  @override
  bool shouldRepaint(_LeaderLinePainter oldDelegate) => true;
}
