import 'package:flutter/material.dart';

/// Short, subtle transitions for pushed Novyn screens.
class NovynPageRoute<T> extends PageRouteBuilder<T> {
  NovynPageRoute({
    required Widget child,
    RouteSettings? settings,
  }) : super(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 180),
          reverseTransitionDuration: const Duration(milliseconds: 160),
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
              reverseCurve: Curves.easeInOutCubic,
            );
            final slide = Tween<Offset>(
              begin: const Offset(0.012, 0),
              end: Offset.zero,
            ).animate(curved);
            final fade = Tween<double>(
              begin: 0.96,
              end: 1,
            ).animate(curved);

            return SlideTransition(
              position: slide,
              child: FadeTransition(
                opacity: fade,
                child: child,
              ),
            );
          },
        );
}
