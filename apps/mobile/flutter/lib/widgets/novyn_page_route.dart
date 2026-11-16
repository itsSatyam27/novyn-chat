import 'package:flutter/material.dart';

/// A lightweight route transition shared by Novyn's pushed screens.
/// The tiny horizontal movement keeps navigation feeling responsive without
/// the cost of a long, full-screen fade animation.
class NovynPageRoute<T> extends PageRouteBuilder<T> {
  NovynPageRoute({
    required Widget child,
    RouteSettings? settings,
  }) : super(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final slide = Tween<Offset>(
              begin: const Offset(0.025, 0),
              end: Offset.zero,
            ).animate(curved);

            return SlideTransition(
              position: slide,
              child: child,
            );
          },
        );
}
