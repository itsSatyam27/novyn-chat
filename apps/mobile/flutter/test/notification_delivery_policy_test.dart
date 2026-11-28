import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/notification_delivery_policy.dart';

void main() {
  group('background notification delivery policy', () {
    test('uses the OS notification only once when FCM provides an alert', () {
      expect(
        shouldRenderLocalBackgroundNotification(hasSystemNotification: true),
        isFalse,
      );
    });

    test('keeps local rendering for data-only background messages', () {
      // This preserves the legacy data-only path, including encrypted DMs
      // that still need local preview handling.
      expect(
        shouldRenderLocalBackgroundNotification(hasSystemNotification: false),
        isTrue,
      );
    });
  });
}
