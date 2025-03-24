import 'package:flutter/material.dart';

class CalculatorKeyboard extends StatelessWidget {
  final ValueChanged<String> onKeyTap;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onEvaluate;
  final VoidCallback onDone;

  const CalculatorKeyboard({
    super.key,
    required this.onKeyTap,
    required this.onBackspace,
    required this.onClear,
    required this.onEvaluate,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromARGB(255, 47, 48, 49),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              Expanded(
                child: TextButton(
                  onPressed: onBackspace,
                  child: const Text('⌫', style: TextStyle(fontSize: 24)),
                ),
              ),
              calculatorButton('+'),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onClear,
                  child: const Text('C', style: TextStyle(fontSize: 24)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: onEvaluate,
                  child: const Text('=', style: TextStyle(fontSize: 24)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: onDone,
                  child: const Text('Done', style: TextStyle(fontSize: 24)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget calculatorButton(String text) {
    return Expanded(
      child: TextButton(
        onPressed: () => onKeyTap(text),
        child: Text(text, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
