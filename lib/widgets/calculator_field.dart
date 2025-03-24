import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'calculator_keyboard.dart';

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
        child: CalculatorKeyboard(
          onKeyTap: _onKeyTap,
          onBackspace: _onBackspace,
          onClear: _onClear,
          onEvaluate: _onEvaluate,
          onDone: _onDone,
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
    // Parse and evaluate the expression using math_expressions
    final parser = Parser();
    final exp = parser.parse(expression);
    final contextModel = ContextModel();
    final result = exp.evaluate(EvaluationType.REAL, contextModel);
    return result.toString();
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
          readOnly: true, // Prevents the default keyboard from appearing
          decoration: const InputDecoration(
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.amber),
              borderRadius: BorderRadius.all(Radius.circular(10.0)),
            ),
            hintText: '0.0',
            labelText: 'Amount',
            prefixText: '\$',
            suffixStyle: TextStyle(color: Colors.green),
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
