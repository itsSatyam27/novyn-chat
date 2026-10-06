import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/widgets/profile_avatar_with_orbit.dart';

void main() {
  testWidgets('orbit and avatar glow follow status changes on the same avatar',
      (tester) async {
    for (final entry in {
      'online': const Color(0xFF10B981),
      'away': const Color(0xFFF59E0B),
      'busy': const Color(0xFFEC4899),
      'invisible': const Color(0xFF64748B),
      'Away': const Color(0xFFF59E0B),
    }.entries) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
        child: ProfileAvatarWithOrbit(
            photoUrl: null, displayName: 'Harsh', status: entry.key),
      ))));
      await tester.pump(const Duration(milliseconds: 200));
      final painted = tester.widget<CustomPaint>(find.descendant(
        of: find.byType(ProfileAvatarWithOrbit),
        matching: find.byType(CustomPaint),
      ));
      expect((painted.painter as dynamic).color, entry.value,
          reason: entry.key);
      final avatar = tester.widget<Container>(find.descendant(
        of: find.byType(ProfileAvatarWithOrbit),
        matching: find.byType(Container),
      ));
      expect((avatar.decoration as BoxDecoration).boxShadow!.single.color,
          entry.value.withValues(alpha: 0.3),
          reason: '${entry.key} glow');
    }
    await tester.pumpWidget(const SizedBox());
  });
}
