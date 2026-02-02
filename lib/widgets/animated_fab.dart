import 'package:flutter/material.dart';
import '../utilities/constants.dart';

/// Animated Floating Action Button with rotation
class AnimatedFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isExpanded;

  const AnimatedFAB({
    super.key,
    required this.onPressed,
    this.isExpanded = false,
  });

  @override
  State<AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<AnimatedFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.75, // 270 degrees (3/4 turn)
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void didUpdateWidget(AnimatedFAB oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FloatingActionButton(
        onPressed: widget.onPressed,
        backgroundColor: AppColors.primary,
        child: RotationTransition(
          turns: _rotationAnimation,
          child: Icon(
            widget.isExpanded ? Icons.close : Icons.add,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
