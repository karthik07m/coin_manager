import 'package:flutter/material.dart';
import '../utilities/constants.dart';

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
      padding: const EdgeInsets.all(AppDimensions.spacing8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildButton('7'),
              _buildButton('8'),
              _buildButton('9'),
              _buildOperatorButton('÷', '/'),
            ],
          ),
          Row(
            children: [
              _buildButton('4'),
              _buildButton('5'),
              _buildButton('6'),
              _buildOperatorButton('×', '*'),
            ],
          ),
          Row(
            children: [
              _buildButton('1'),
              _buildButton('2'),
              _buildButton('3'),
              _buildOperatorButton('−', '-'),
            ],
          ),
          Row(
            children: [
              _buildButton('0'),
              _buildButton('.'),
              _buildActionButton(
                icon: Icons.backspace_outlined,
                onPressed: onBackspace,
              ),
              _buildOperatorButton('+', '+'),
            ],
          ),
          Row(
            children: [
              _buildActionButton(
                text: 'C',
                onPressed: onClear,
                color: Colors.red,
              ),
              _buildActionButton(
                text: '=',
                onPressed: onEvaluate,
                color: AppColors.primary,
              ),
              _buildActionButton(
                text: 'Done',
                onPressed: onDone,
                color: AppColors.primary,
                isWide: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String text) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing4),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          child: InkWell(
            onTap: () => onKeyTap(text),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spacing16,
              ),
              child: Center(
                child: Text(
                  text,
                  style: AppTextStyles.amount.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorButton(String displayText, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing4),
        child: Material(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          child: InkWell(
            onTap: () => onKeyTap(value),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spacing16,
              ),
              child: Center(
                child: Text(
                  displayText,
                  style: AppTextStyles.amount.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    String? text,
    IconData? icon,
    required VoidCallback onPressed,
    Color? color,
    bool isWide = false,
  }) {
    return Expanded(
      flex: isWide ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing4),
        child: Material(
          color: color?.withOpacity(0.1) ?? AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spacing16,
              ),
              child: Center(
                child: text != null
                    ? Text(
                        text,
                        style: AppTextStyles.amount.copyWith(
                          color: color ?? AppColors.textPrimary,
                        ),
                      )
                    : Icon(
                        icon,
                        color: color ?? AppColors.textPrimary,
                        size: AppDimensions.iconMedium,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
