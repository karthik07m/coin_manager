import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'calculator_keyboard.dart';
import '../utilities/constants.dart';

class CalculatorTextFormField extends StatefulWidget {
  final TextEditingController controller;

  const CalculatorTextFormField({super.key, required this.controller});

  @override
  CalculatorTextFormFieldState createState() => CalculatorTextFormFieldState();
}

class CalculatorTextFormFieldState extends State<CalculatorTextFormField> {
  late FocusNode _focusNode;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_focusListener);
  }

  void _focusListener() {
    if (_focusNode.hasFocus) {
      _showKeyboardOverlay();
    } else {
      _removeKeyboardOverlay();
    }
  }

  void _showKeyboardOverlay() {
    if (_overlayEntry != null) {
      return;
    }
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Material(
          color: AppColors.surface,
          elevation: AppDimensions.elevationMedium,
          child: CalculatorKeyboard(
            onKeyTap: _onKeyTap,
            onBackspace: _onBackspace,
            onClear: _onClear,
            onEvaluate: _onEvaluate,
            onDone: _onDone,
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeKeyboardOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onKeyTap(String key) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      key,
    );

    widget.controller.text = newText;
    widget.controller.selection =
        TextSelection.collapsed(offset: selection.start + key.length);
  }

  void _onBackspace() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (selection.start > 0) {
      final newText = text.replaceRange(
        selection.start - 1,
        selection.start,
        '',
      );

      widget.controller.text = newText;
      widget.controller.selection =
          TextSelection.collapsed(offset: selection.start - 1);
    }
  }

  void _onClear() {
    widget.controller.clear();
  }

  void _onEvaluate() {
    try {
      widget.controller.text = _evaluateExpression(widget.controller.text);
    } catch (e) {
      widget.controller.text = "0.0";
    }
  }

  String _evaluateExpression(String expression) {
    if (expression.isEmpty) return "0.0";
    try {
      final parser = Parser();
      final exp = parser.parse(expression);
      final contextModel = ContextModel();
      final result = exp.evaluate(EvaluationType.REAL, contextModel);
      return result.toString();
    } catch (e) {
      return "0.0";
    }
  }

  void _onDone() {
    _onEvaluate();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _focusNode.requestFocus();
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          readOnly: true,
          style: AppTextStyles.amount.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            labelText: 'Amount',
            labelStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            hintText: '0.00',
            hintStyle: AppTextStyles.amount.copyWith(
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            prefixText: '\$ ',
            prefixStyle: AppTextStyles.amount.copyWith(
              color: AppColors.textPrimary,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              borderSide: BorderSide(
                color: AppColors.primary.withOpacity(0.1),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              borderSide: BorderSide(
                color: AppColors.primary.withOpacity(0.1),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_focusListener);
    _focusNode.dispose();
    _removeKeyboardOverlay();
    super.dispose();
  }
}
