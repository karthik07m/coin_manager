import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:math_expressions/math_expressions.dart';
import 'calculator_keyboard.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

class CalculatorTextFormField extends StatefulWidget {
  final TextEditingController controller;

  const CalculatorTextFormField({super.key, required this.controller});

  @override
  CalculatorTextFormFieldState createState() => CalculatorTextFormFieldState();
}

class CalculatorTextFormFieldState extends State<CalculatorTextFormField> {
  // Use ValueNotifier for targeted rebuilds instead of setState
  final ValueNotifier<bool> _showKeyboard = ValueNotifier<bool>(false);
  final ValueNotifier<String> _displayValue = ValueNotifier<String>('0.00');

  int _centsValue = 0;

  @override
  void initState() {
    super.initState();
    _initializeFromController();

    // Sync display value with controller
    widget.controller.addListener(_syncFromController);
  }

  void _initializeFromController() {
    if (widget.controller.text.isNotEmpty) {
      try {
        final value = double.parse(widget.controller.text.replaceAll(',', ''));
        _centsValue = (value * 100).round();
        _displayValue.value = _formatCurrency(_centsValue / 100.0);
      } catch (e) {
        _centsValue = 0;
        _displayValue.value = '0.00';
      }
    }
  }

  void _syncFromController() {
    // Only sync if controller has a valid number
    final text = widget.controller.text.replaceAll(',', '');
    final value = double.tryParse(text);
    if (value != null) {
      _displayValue.value = _formatCurrency(value);
    }
  }

  void _toggleKeyboard() {
    // Dismiss system keyboard first
    FocusManager.instance.primaryFocus?.unfocus();

    HapticFeedback.selectionClick();
    _showKeyboard.value = !_showKeyboard.value;
  }

  void _onKeyTap(String key) {
    HapticFeedback.selectionClick();

    if (['+', '-', '*', '/'].contains(key)) {
      // Operator - append to expression
      final current = widget.controller.text;
      widget.controller.text = current + key;
      _displayValue.value = widget.controller.text;
    } else if (key == '.') {
      // Ignore - handled automatically
    } else {
      // Number - cents-first entry
      final digit = int.tryParse(key) ?? 0;
      _centsValue = _centsValue * 10 + digit;
      _updateDisplay();
    }
  }

  void _updateDisplay() {
    final dollars = _centsValue / 100.0;
    final formatted = _formatCurrency(dollars);
    widget.controller.text = formatted;
    _displayValue.value = formatted;
  }

  // Optimized currency formatter - pure function, no rebuilds
  String _formatCurrency(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    if (intPart.length <= 3) {
      return '$intPart.$decPart';
    }

    // Add commas for thousands
    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
      count++;
    }

    return '${buffer.toString().split('').reversed.join()}.$decPart';
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    _centsValue = _centsValue ~/ 10;
    _updateDisplay();
  }

  void _onClear() {
    HapticFeedback.heavyImpact();
    _centsValue = 0;
    widget.controller.text = '0.00';
    _displayValue.value = '0.00';
  }

  void _onEvaluate() {
    HapticFeedback.mediumImpact();
    try {
      String expression = widget.controller.text.replaceAll(',', '');
      final parser = GrammarParser();
      final exp = parser.parse(expression);
      final contextModel = ContextModel();
      final result = RealEvaluator(contextModel).evaluate(exp);
      _centsValue = (result * 100).round();
      _updateDisplay();
    } catch (e) {
      // Keep current value on error
    }
  }

  void _onDone() {
    _onEvaluate();
    _showKeyboard.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Amount Input Field - uses ValueListenableBuilder for targeted rebuilds
        GestureDetector(
          onTap: _toggleKeyboard,
          child: ValueListenableBuilder<bool>(
            valueListenable: _showKeyboard,
            builder: (context, showKeyboard, child) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: showKeyboard
                        ? AppColors.primary
                        : AppColors.divider.withValues(alpha: 0.3),
                    width: showKeyboard ? 2 : 1,
                  ),
                  boxShadow: showKeyboard
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: child,
              );
            },
            child: Row(
              children: [
                // Dollar badge - const widget, never rebuilds
                const _DollarBadge(),
                const SizedBox(width: 16),
                // Amount display - only rebuilds when value changes
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _displayValue,
                    builder: (context, value, _) {
                      return Text(
                        value,
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Calculator Keyboard - wrapped in RepaintBoundary for isolation
        ValueListenableBuilder<bool>(
          valueListenable: _showKeyboard,
          builder: (context, showKeyboard, _) {
            if (!showKeyboard) return const SizedBox.shrink();

            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: CalculatorKeyboard(
                  onKeyTap: _onKeyTap,
                  onBackspace: _onBackspace,
                  onClear: _onClear,
                  onEvaluate: _onEvaluate,
                  onDone: _onDone,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    _showKeyboard.dispose();
    _displayValue.dispose();
    super.dispose();
  }
}

// Extracted const widget - zero rebuilds
class _DollarBadge extends StatelessWidget {
  const _DollarBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '\$',
        style: AppTextStyles.h2.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
    );
  }
}
