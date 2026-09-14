import 'package:flutter/material.dart';

/// Cashew's route motion: the incoming page fades in while rising 5%. Quick
/// in, quicker out, so going back feels instant.
class PageTransitions {
  static Widget _fadeUp(
      BuildContext context, Animation<double> animation, Widget child) {
    // The OS "Remove animations" setting: motion is a vestibular trigger for
    // some users, and Flutter doesn't honour it for custom routes.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return SlideTransition(
      position: animation.drive(
          Tween(begin: const Offset(0, 0.05), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic))),
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  static Route<T> fadeUp<T>(Widget page, {RouteSettings? settings}) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          _fadeUp(context, animation, child),
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 150),
    );
  }
}

/// The same motion for routes built by the framework (the named `routes`
/// table, MaterialPageRoute), set on the theme in main.dart.
class FadeUpPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeUpPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
          PageRoute<T> route,
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child) =>
      PageTransitions._fadeUp(context, animation, child);
}
