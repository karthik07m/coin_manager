import 'package:flutter/material.dart';
import '../utilities/constants.dart';

/// Animated progress bar with smooth transitions
class AnimatedProgressBar extends StatefulWidget {
  final double value; // 0.0 to 1.0
  final Color? color;
  final Color? backgroundColor;
  final double height;
  final Duration duration;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.height = 8.0,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _updateAnimations();
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _updateAnimations();
      _controller.forward(from: 0.0);
    }
  }

  void _updateAnimations() {
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.value.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Color transition based on value
    Color targetColor = widget.color ?? AppColors.primary;
    if (widget.value > 1.0) {
      targetColor = AppColors.negative; // Over budget
    } else if (widget.value > 0.8) {
      targetColor = AppColors.warning; // Near budget
    }

    _colorAnimation = ColorTween(
      begin: AppColors.primary.withValues(alpha: 0.3),
      end: targetColor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor ??
                Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: _colorAnimation.value,
                borderRadius: BorderRadius.circular(widget.height / 2),
                boxShadow: [
                  BoxShadow(
                    color: (_colorAnimation.value ?? AppColors.primary)
                        .withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
