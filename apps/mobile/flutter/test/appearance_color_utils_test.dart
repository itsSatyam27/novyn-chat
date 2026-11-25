import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/utils/appearance_color_utils.dart';

void main() {
  group('resolveAccentSwatchColor', () {
    const accent = Color(0xFF6D5DFC);
    const surface = Color(0xFFF4F2FA);

    test('preserves the selected color while accent is enabled', () {
      expect(
        resolveAccentSwatchColor(
          color: accent,
          surface: surface,
          enabled: true,
        ),
        accent,
      );
    });

    test('mutes the selected color while accent is disabled', () {
      final muted = resolveAccentSwatchColor(
        color: accent,
        surface: surface,
        enabled: false,
      );
      final expected = Color.lerp(accent, surface, .62);

      expect(muted, expected);
      expect(muted, isNot(accent));
      expect(muted, isNot(surface));
    });
  });
}
