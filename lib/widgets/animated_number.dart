import 'package:flutter/material.dart';

/// Animated counting number widget
/// Smoothly animates from one number to another
class AnimatedNumber extends StatefulWidget {
  final double value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final String Function(double)? formatter;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
    this.formatter,
  });

  @override
  State<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<AnimatedNumber>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(
      begin: _previousValue,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.value != oldWidget.value) {
      _previousValue = _animation.value;

      _animation = Tween<double>(
        begin: _previousValue,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ));

      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    if (widget.formatter != null) {
      return widget.formatter!(value);
    }

    // Default formatting: round to 2 decimal places
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          _formatNumber(_animation.value),
          style: widget.style,
        );
      },
    );
  }
}

/// Animated money display with currency symbol
class AnimatedMoney extends StatelessWidget {
  final double amount;
  final String currencySymbol;
  final TextStyle? style;
  final Duration duration;
  final bool showSign;

  const AnimatedMoney({
    super.key,
    required this.amount,
    required this.currencySymbol,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.showSign = false,
  });

  String _formatMoney(double value) {
    final absValue = value.abs();
    final sign = showSign && value >= 0 ? '+' : '';

    // Format with commas
    final formatted = _formatWithCommas(absValue);

    return '$sign$currencySymbol$formatted';
  }

  String _formatWithCommas(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    // Add commas to integer part
    final regex = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final formattedInteger =
        integerPart.replaceAllMapped(regex, (match) => ',');

    return '$formattedInteger.$decimalPart';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedNumber(
      value: amount,
      style: style,
      duration: duration,
      formatter: _formatMoney,
    );
  }
}
