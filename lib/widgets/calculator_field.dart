import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:math_expressions/math_expressions.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

class CalculatorTextFormField extends StatefulWidget {
  final TextEditingController controller;
  final String currencySymbol;

  const CalculatorTextFormField({
    super.key,
    required this.controller,
    this.currencySymbol = '\$',
  });

  @override
  CalculatorTextFormFieldState createState() => CalculatorTextFormFieldState();
}

class CalculatorTextFormFieldState extends State<CalculatorTextFormField> {
  final ValueNotifier<String> _displayValue = ValueNotifier<String>('0');

  @override
  void initState() {
    super.initState();
    _initializeFromController();
    widget.controller.addListener(_syncFromController);
  }

  void _initializeFromController() {
    if (widget.controller.text.isNotEmpty) {
      _displayValue.value = widget.controller.text;
    }
  }

  void _syncFromController() {
    final text = widget.controller.text;
    if (text.isNotEmpty) {
      _displayValue.value = text;
    }
  }

  void _showCalculatorBottomSheet() {
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CalculatorBottomSheet(
        initialValue: widget.controller.text,
        currencySymbol: widget.currencySymbol,
        onDone: (value) {
          setState(() {
            widget.controller.text = value;
            _displayValue.value = value;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showCalculatorBottomSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: context.textSecondary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: _displayValue,
                builder: (context, display, _) {
                  return Text(
                    '${widget.currencySymbol}${display.isEmpty ? '0' : display}',
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                    textAlign: TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
            Icon(
              Icons.calculate,
              color: context.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _displayValue.dispose();
    super.dispose();
  }
}

class _CalculatorBottomSheet extends StatefulWidget {
  final String initialValue;
  final String currencySymbol;
  final Function(String) onDone;

  const _CalculatorBottomSheet({
    required this.initialValue,
    required this.currencySymbol,
    required this.onDone,
  });

  @override
  State<_CalculatorBottomSheet> createState() => _CalculatorBottomSheetState();
}

class _CalculatorBottomSheetState extends State<_CalculatorBottomSheet> {
  late String _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue.isEmpty ? '0' : widget.initialValue;
  }

  void _onKeyTap(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      String cleanValue = _currentValue.replaceAll(',', '');
      if (cleanValue == '0') cleanValue = '';

      if (['+', '-', '×', '÷'].contains(key)) {
        // Operator
        if (cleanValue.isEmpty) return;
        _currentValue = cleanValue + key;
      } else if (key == '.') {
        // Decimal point
        if (cleanValue.contains(RegExp(r'[+\-×÷]'))) {
          final parts = cleanValue.split(RegExp(r'[+\-×÷]'));
          if (!parts.last.contains('.')) {
            _currentValue = cleanValue + key;
          }
        } else if (!cleanValue.contains('.')) {
          _currentValue = cleanValue.isEmpty ? '0.' : cleanValue + key;
        }
      } else {
        // Number
        _currentValue = cleanValue + key;
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_currentValue.isNotEmpty && _currentValue != '0') {
        _currentValue = _currentValue.substring(0, _currentValue.length - 1);
        if (_currentValue.isEmpty) _currentValue = '0';
      }
    });
  }

  void _onEvaluate() {
    HapticFeedback.mediumImpact();
    try {
      String expression = _currentValue
          .replaceAll(',', '')
          .replaceAll('×', '*')
          .replaceAll('÷', '/');

      if (expression.contains(RegExp(r'[+\-*/]'))) {
        final parser = GrammarParser();
        final exp = parser.parse(expression);
        final contextModel = ContextModel();
        final result = RealEvaluator(contextModel).evaluate(exp);
        setState(() {
          _currentValue = result.toString();
        });
      }
    } catch (e) {
      // Keep current value on error
    }
  }

  void _onDone() {
    _onEvaluate();
    widget.onDone(_currentValue);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Enter Amount',
                style: AppTextStyles.h2.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Amount Display
              Container(
                width: double.infinity,
                alignment: Alignment.centerRight,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Text(
                  '${widget.currencySymbol}$_currentValue',
                  style: AppTextStyles.h1.copyWith(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),

              // Calculator Keypad - Dark theme
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    _buildKeyRow(context, ['7', '8', '9', '÷']),
                    const SizedBox(height: 12),
                    _buildKeyRow(context, ['4', '5', '6', '×']),
                    const SizedBox(height: 12),
                    _buildKeyRow(context, ['1', '2', '3', '-']),
                    const SizedBox(height: 12),
                    _buildKeyRow(context, ['0', '.', '⌫', '+']),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Set Amount Button - Green accent
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Done',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyRow(BuildContext context, List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(context, key)).toList(),
    );
  }

  Widget _buildKey(BuildContext context, String key) {
    final isOperator = ['+', '-', '×', '÷'].contains(key);
    final isBackspace = key == '⌫';

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: AspectRatio(
          aspectRatio: 1,
          child: Material(
            color: isOperator
                ? AppColors.primary.withValues(alpha: 0.15)
                : context.appSurfaceLight,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () {
                if (isBackspace) {
                  _onBackspace();
                } else {
                  _onKeyTap(key);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                alignment: Alignment.center,
                child: isBackspace
                    ? Icon(
                        Icons.backspace_outlined,
                        size: 24,
                        color: context.textSecondary,
                      )
                    : Text(
                        key,
                        style: TextStyle(
                          fontSize: isOperator ? 28 : 24,
                          fontWeight: FontWeight.w500,
                          color: isOperator
                              ? AppColors.primary
                              : context.textPrimary,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
