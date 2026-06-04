import 'package:flutter/material.dart';

/// Custom scroll physics for smoother scrolling experience
class CustomScrollPhysics extends ScrollPhysics {
  const CustomScrollPhysics({super.parent});

  @override
  CustomScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CustomScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.5,
        stiffness: 100.0,
        damping: 15.0,
      );

  @override
  double get minFlingVelocity => 50.0;

  @override
  double get maxFlingVelocity => 8000.0;

  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}

/// Bouncy scroll physics for iOS-like feel
class BouncyScrollPhysics extends ScrollPhysics {
  const BouncyScrollPhysics({super.parent});

  @override
  BouncyScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return BouncyScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.4,
        stiffness: 80.0,
        damping: 12.0,
      );

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (offset < 0.0 && position.pixels <= position.minScrollExtent) {
      return offset * 0.5;
    }
    if (offset > 0.0 && position.pixels >= position.maxScrollExtent) {
      return offset * 0.5;
    }
    return offset;
  }

  @override
  double get minFlingVelocity => 100.0;

  @override
  double get maxFlingVelocity => 5000.0;
}
