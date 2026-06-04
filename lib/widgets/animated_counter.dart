import 'package:flutter/material.dart';

/// Animated counter that smoothly transitions between numbers
class AnimatedCounter extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final Duration duration;
  final String prefix;
  final String suffix;
  final int decimalPlaces;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 500),
    this.prefix = '',
    this.suffix = '',
    this.decimalPlaces = 2,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.fastOutSlowIn,
      builder: (context, value, child) {
        return Text(
          '$prefix${_formatNumber(value)}$suffix',
          style: style,
        );
      },
    );
  }

  String _formatNumber(double value) {
    if (decimalPlaces == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(decimalPlaces);
  }
}

/// Animated counter with comma formatting for currency
class AnimatedCurrencyCounter extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final Duration duration;
  final String currencySymbol;
  final bool showSign;

  const AnimatedCurrencyCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.currencySymbol = '\$',
    this.showSign = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.fastOutSlowIn,
      builder: (context, animatedValue, child) {
        final sign = showSign && animatedValue >= 0 ? '+' : '';
        return Text(
          '$sign${_formatCurrency(animatedValue)}',
          style: style,
        );
      },
    );
  }

  String _formatCurrency(double value) {
    final absValue = value.abs();
    final formatted = _addCommas(absValue.toStringAsFixed(2));
    final signPrefix = value < 0 ? '-' : '';
    return '$signPrefix$currencySymbol$formatted';
  }

  String _addCommas(String value) {
    final parts = value.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';

    final buffer = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(integerPart[i]);
    }

    return buffer.toString() + decimalPart;
  }
}

/// Animated percentage counter
class AnimatedPercentageCounter extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final Duration duration;
  final int decimalPlaces;

  const AnimatedPercentageCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 500),
    this.decimalPlaces = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.fastOutSlowIn,
      builder: (context, value, child) {
        return Text(
          '${value.toStringAsFixed(decimalPlaces)}%',
          style: style,
        );
      },
    );
  }
}
