import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../utilities/page_transitions.dart';
import '../utilities/theme_helper.dart';

/// Cashew's tap feel for any card: the card's own [Material] owns the ink, so
/// the sparkle ripple paints over its fill (an InkWell above a coloured
/// Container hides it), and the card dips slightly while held.
///
/// Give it an [openPage] and the card grows into that page (Material's
/// container transform) instead of the page arriving on its own.
class Tappable extends StatefulWidget {
  const Tappable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.openPage,
    this.color,
    this.borderRadius = 0,
    this.padding = EdgeInsets.zero,
    this.pressedScale = 0.97,
  });

  final Widget child;

  /// Runs on tap; with [openPage] it runs first (e.g. haptics).
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Page this card expands into when tapped.
  final Widget? openPage;

  /// Card fill. Null keeps whatever is behind it.
  final Color? color;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double pressedScale;

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool _pressed = false;

  Widget _ink(VoidCallback? onTap) => InkWell(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        onTap: onTap,
        onLongPress: widget.onLongPress,
        onHighlightChanged: (value) => setState(() => _pressed = value),
        child: Padding(padding: widget.padding, child: widget.child),
      );

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final animate = !MediaQuery.disableAnimationsOf(context);
    final page = widget.openPage;

    final Widget card;
    if (page != null && animate) {
      card = OpenContainer(
        tappable: false,
        transitionType: ContainerTransitionType.fade,
        transitionDuration: const Duration(milliseconds: 400),
        closedElevation: 0,
        openElevation: 0,
        closedColor: widget.color ?? Colors.transparent,
        openColor: context.appBackground,
        middleColor: context.appBackground,
        closedShape: RoundedRectangleBorder(borderRadius: radius),
        openBuilder: (context, _) => page,
        closedBuilder: (context, open) => _ink(() {
          widget.onTap?.call();
          open();
        }),
      );
    } else {
      card = Material(
        type: widget.color == null
            ? MaterialType.transparency
            : MaterialType.canvas,
        color: widget.color,
        borderRadius: radius,
        child: _ink(page == null
            ? widget.onTap
            : () {
                widget.onTap?.call();
                // "Remove animations" is on: no expand, just the page.
                Navigator.push(context, PageTransitions.fadeUp(page));
              }),
      );
    }

    return AnimatedScale(
      scale: _pressed && animate ? widget.pressedScale : 1,
      // Sink quickly, settle back with a slight overshoot.
      duration: Duration(milliseconds: _pressed ? 120 : 280),
      curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
      child: card,
    );
  }
}
