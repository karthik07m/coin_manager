import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

/// Optimized calculator keyboard with best practices:
/// - const constructors where possible
/// - RepaintBoundary for button isolation
/// - Minimal rebuilds with StatelessWidget buttons
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
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Row 1: 7 8 9 ÷
              Row(
                children: [
                  _NumberButton(text: '7', onTap: () => onKeyTap('7')),
                  _NumberButton(text: '8', onTap: () => onKeyTap('8')),
                  _NumberButton(text: '9', onTap: () => onKeyTap('9')),
                  _OperatorButton(display: '÷', onTap: () => onKeyTap('/')),
                ],
              ),
              const SizedBox(height: 8),
              // Row 2: 4 5 6 ×
              Row(
                children: [
                  _NumberButton(text: '4', onTap: () => onKeyTap('4')),
                  _NumberButton(text: '5', onTap: () => onKeyTap('5')),
                  _NumberButton(text: '6', onTap: () => onKeyTap('6')),
                  _OperatorButton(display: '×', onTap: () => onKeyTap('*')),
                ],
              ),
              const SizedBox(height: 8),
              // Row 3: 1 2 3 −
              Row(
                children: [
                  _NumberButton(text: '1', onTap: () => onKeyTap('1')),
                  _NumberButton(text: '2', onTap: () => onKeyTap('2')),
                  _NumberButton(text: '3', onTap: () => onKeyTap('3')),
                  _OperatorButton(display: '−', onTap: () => onKeyTap('-')),
                ],
              ),
              const SizedBox(height: 8),
              // Row 4: 0 . ⌫ +
              Row(
                children: [
                  _NumberButton(text: '0', onTap: () => onKeyTap('0')),
                  _NumberButton(text: '.', onTap: () => onKeyTap('.')),
                  _IconButton(
                      icon: Icons.backspace_rounded, onTap: onBackspace),
                  _OperatorButton(display: '+', onTap: () => onKeyTap('+')),
                ],
              ),
              const SizedBox(height: 12),
              // Row 5: C = Done
              Row(
                children: [
                  _ActionButton(
                    text: 'C',
                    onTap: onClear,
                    color: AppColors.negative,
                  ),
                  _ActionButton(
                    text: '=',
                    onTap: onEvaluate,
                    color: AppColors.primary,
                    isPrimary: true,
                  ),
                  _DoneButton(onTap: onDone),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Extracted StatelessWidget buttons for optimal rendering
class _NumberButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _NumberButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _TapButton(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: context.appBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Text(
                text,
                style: AppTextStyles.h2.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OperatorButton extends StatelessWidget {
  final String display;
  final VoidCallback onTap;

  const _OperatorButton({required this.display, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _TapButton(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Text(
                display,
                style: AppTextStyles.h2.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _TapButton(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: context.appBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                color: context.textSecondary,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;
  final bool isPrimary;

  const _ActionButton({
    required this.text,
    required this.onTap,
    required this.color,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _TapButton(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: isPrimary
                  ? LinearGradient(
                      colors: [color, color.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isPrimary ? null : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: isPrimary
                  ? null
                  : Border.all(color: color.withValues(alpha: 0.3)),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                text,
                style: AppTextStyles.h3.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isPrimary ? Colors.white : color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DoneButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _TapButton(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.positive,
                  AppColors.positive.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.positive.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Done',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Optimized tap handler with minimal rebuilds
class _TapButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TapButton({required this.child, required this.onTap});

  @override
  State<_TapButton> createState() => _TapButtonState();
}

class _TapButtonState extends State<_TapButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
