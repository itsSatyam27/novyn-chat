import 'package:flutter/material.dart';

import 'novyn_alert.dart';

/// Backward-compatible API for call sites that still use NovynToast.show.
/// The rendering is delegated to the user's selected Appearance alert style.
class NovynToast {
  NovynToast._();

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    NovynAlert.show(
      context,
      message,
      isError: isError,
      duration: duration,
      haptic: false,
    );
  }
}
