import 'package:flutter/material.dart';

/// Custom page transitions for smooth navigation
class PageTransitions {
  static const Curve _forwardCurve = Curves.easeOutCubic;
  static const Curve _reverseCurve = Curves.easeInCubic;

  /// Slide transition from right (default for most screens).
  /// Slide-only: the incoming page is opaque, so a full-page fade/scale would
  /// only add a per-frame offscreen layer (jank) without visible benefit.
  static Route<T> slideFromRight<T>(Widget page, {RouteSettings? settings}) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween(
          begin: const Offset(0.18, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: _forwardCurve,
          reverseCurve: _reverseCurve,
        ));

        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
    );
  }

  /// Slide transition from bottom (for modal-like screens).
  /// Slide-only for the same reason as [slideFromRight] — a full-page fade on
  /// an opaque modal just forces an offscreen layer every frame.
  static Route<T> slideFromBottom<T>(Widget page, {RouteSettings? settings}) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween(
          begin: const Offset(0.0, 0.18),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: _forwardCurve,
          reverseCurve: _reverseCurve,
        ));

        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 180),
    );
  }

  /// Fade transition (for overlays and lightweight screens)
  static Route<T> fade<T>(Widget page, {RouteSettings? settings}) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: _forwardCurve,
          reverseCurve: _reverseCurve,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 170),
    );
  }

  /// Scale transition with fade (for detail screens)
  static Route<T> scaleWithFade<T>(Widget page, {RouteSettings? settings}) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: _forwardCurve,
          reverseCurve: _reverseCurve,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 170),
    );
  }

  /// Shared axis transition (Material Design)
  static Route<T> sharedAxisVertical<T>(Widget page,
      {RouteSettings? settings}) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 0.03),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: _forwardCurve,
          reverseCurve: _reverseCurve,
        ));

        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: _forwardCurve,
          reverseCurve: _reverseCurve,
        ));

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
    );
  }

  /// Custom page route builder based on screen type
  static Route<T> buildRoute<T>({
    required Widget page,
    required String routeName,
    RouteSettings? settings,
  }) {
    // Modal-like screens get slide from bottom
    if (routeName.contains('Form') ||
        routeName.contains('create') ||
        routeName.contains('add')) {
      return slideFromBottom(page, settings: settings);
    }

    // Detail screens get scale with fade
    if (routeName.contains('Detail') || routeName.contains('detail')) {
      return scaleWithFade(page, settings: settings);
    }

    // Calendar and charts get fade
    if (routeName.contains('calendar') ||
        routeName.contains('chart') ||
        routeName.contains('Charts')) {
      return fade(page, settings: settings);
    }

    // Default: slide from right
    return slideFromRight(page, settings: settings);
  }
}
