import 'package:flutter/material.dart';

/// App-level overlay for an active call. It is rendered above the Navigator so
/// the mini call stays visible while users move between app routes.
class CallOverlayService {
  CallOverlayService._();

  static final ValueNotifier<Widget?> miniCall = ValueNotifier<Widget?>(null);

  static void show(Widget miniCallWidget) {
    miniCall.value = miniCallWidget;
  }

  static void hide() {
    miniCall.value = null;
  }
}
