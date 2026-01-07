import 'package:flutter/material.dart';

enum MascotExpression { happy, waving, thinking, celebrating, pointing }

class MascotWidget extends StatelessWidget {
  final String? message;
  final double size;
  final MascotExpression expression;
  final bool showSpeechBubble;
  final bool animate;

  const MascotWidget({
    super.key,
    this.message,
    this.size = 120,
    this.expression = MascotExpression.happy,
    this.showSpeechBubble = true,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSpeechBubble && message != null) _buildSpeechBubble(context),
        if (showSpeechBubble && message != null) const SizedBox(height: 12),
        _buildMascotImage(),
      ],
    );
  }

  Widget _buildMascotImage() {
    // User requested to remove images. Returning empty box.
    return const SizedBox.shrink();
  }

  Widget _buildSpeechBubble(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1), // Glass effect
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        message!,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white, // Force white text for dark mode
            ),
      ),
    );
  }
}
