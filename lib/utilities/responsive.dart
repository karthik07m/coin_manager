import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Material 3 window size classes.
///
/// - [compact]  : phones in portrait (< 600dp)
/// - [medium]   : large phones landscape / small tablets (600–839dp)
/// - [expanded] : tablets and desktop (>= 840dp)
enum WindowSize { compact, medium, expanded }

/// Screen-size helpers so the UI adapts to any device instead of relying on
/// hardcoded pixel values tuned for one phone.
///
/// Usage: `context.isCompact`, `context.responsive(12, md: 16, lg: 20)`,
/// `context.gridColumns(minTileWidth: 96)`.
extension Responsive on BuildContext {
  Size get _size => MediaQuery.sizeOf(this);

  double get screenWidth => _size.width;
  double get screenHeight => _size.height;

  WindowSize get windowSize {
    final w = screenWidth;
    if (w >= 840) return WindowSize.expanded;
    if (w >= 600) return WindowSize.medium;
    return WindowSize.compact;
  }

  bool get isCompact => windowSize == WindowSize.compact;
  bool get isMedium => windowSize == WindowSize.medium;
  bool get isExpanded => windowSize == WindowSize.expanded;

  /// True on very small handsets (e.g. iPhone SE, 320–360dp wide) where
  /// default paddings and font sizes need to tighten up.
  bool get isSmallPhone => screenWidth < 360;

  /// True on short screens where tall fixed-height blocks (charts, hero
  /// cards) would push primary actions off-screen.
  bool get isShortScreen => screenHeight < 700;

  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;

  /// Picks a value for the current window size.
  ///
  /// `context.responsive(16, md: 24, lg: 32)` → 16 on phones, 24 on small
  /// tablets, 32 on large screens. [md]/[lg] fall back to the smaller value
  /// when omitted, so a single argument is always safe.
  T responsive<T>(T compact, {T? md, T? lg}) {
    switch (windowSize) {
      case WindowSize.expanded:
        return lg ?? md ?? compact;
      case WindowSize.medium:
        return md ?? compact;
      case WindowSize.compact:
        return compact;
    }
  }

  /// Horizontal page padding that grows with the window.
  double get pagePadding => responsive(
        isSmallPhone ? 12.0 : 16.0,
        md: 24.0,
        lg: 32.0,
      );

  /// Caps content width on tablets/desktop so lines and cards don't stretch
  /// uncomfortably wide. Wrap page bodies in [constrainedContent].
  double get maxContentWidth => responsive(double.infinity, md: 720.0, lg: 900.0);

  /// Centers [child] within [maxContentWidth] on large screens; a no-op on
  /// phones.
  Widget constrainedContent(Widget child) {
    final max = maxContentWidth;
    if (max == double.infinity) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: child,
      ),
    );
  }

  /// Number of grid columns that fit, given a minimum comfortable tile width.
  ///
  /// Prefer this over a hardcoded `crossAxisCount` so icon/category grids
  /// show more columns on tablets and never squash on small phones.
  int gridColumns({
    required double minTileWidth,
    double spacing = 12,
    double horizontalPadding = 0,
    int min = 2,
    int max = 8,
  }) {
    final available = screenWidth - horizontalPadding;
    if (available <= 0) return min;
    final columns =
        ((available + spacing) / (minTileWidth + spacing)).floor();
    return columns.clamp(min, max);
  }

  /// Height for a chart/visual block, scaled to the viewport instead of a
  /// fixed pixel value. [fraction] is of the screen height.
  double chartHeight({
    double fraction = 0.24,
    double min = 150,
    double max = 320,
  }) {
    return (screenHeight * fraction).clamp(min, max);
  }

  /// Scales a font size gently with screen width so text stays proportionate
  /// on small phones and tablets, without letting it run away.
  double scaledFont(double size) {
    final factor = responsive(isSmallPhone ? 0.92 : 1.0, md: 1.05, lg: 1.1);
    return size * factor;
  }
}

/// Clamps the OS text-scale factor so very large accessibility font settings
/// enlarge text without breaking fixed-height rows and cards.
///
/// Applied once at the app root via `MaterialApp.builder`.
class ClampedTextScale extends StatelessWidget {
  final Widget child;
  final double min;
  final double max;

  const ClampedTextScale({
    super.key,
    required this.child,
    this.min = 0.85,
    this.max = 1.3,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = mq.textScaler.scale(1.0);
    final clamped = math.min(math.max(scale, min), max);
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(clamped)),
      child: child,
    );
  }
}
