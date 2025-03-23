import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

class CalculatorDialog extends StatefulWidget {
  const CalculatorDialog({super.key});

  @override
  CalculatorDialogState createState() => CalculatorDialogState();
}

class CalculatorDialogState extends State<CalculatorDialog> {
  String expression = '';

  void numClick(String text) {
    setState(() {
      expression += text;
    });
  }

  void clear(String text) {
    setState(() {
      expression = '';
    });
  }

  void evaluate(String text) {
    Parser p = Parser();
    Expression exp = p.parse(expression);
    ContextModel cm = ContextModel();
    double eval = exp.evaluate(EvaluationType.REAL, cm);
    setState(() {
      expression = eval.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Calculator'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(expression, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 20),
          Row(
            children: [
              calculatorButton('7'),
              calculatorButton('8'),
              calculatorButton('9'),
              calculatorButton('/'),
            ],
          ),
          Row(
            children: [
              calculatorButton('4'),
              calculatorButton('5'),
              calculatorButton('6'),
              calculatorButton('*'),
            ],
          ),
          Row(
            children: [
              calculatorButton('1'),
              calculatorButton('2'),
              calculatorButton('3'),
              calculatorButton('-'),
            ],
          ),
          Row(
            children: [
              calculatorButton('0'),
              calculatorButton('.'),
              calculatorButton('='),
              calculatorButton('+'),
            ],
          ),
          Row(
            children: [
              calculatorButton('C'),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(expression);
          },
          child: const Text('OK'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget calculatorButton(String text) {
    return Expanded(
      child: TextButton(
        onPressed: () {
          if (text == '=') {
            evaluate(text);
          } else if (text == 'C') {
            clear(text);
          } else {
            numClick(text);
          }
        },
        child: Text(text, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
