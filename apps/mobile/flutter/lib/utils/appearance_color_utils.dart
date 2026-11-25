import 'package:flutter/material.dart';

/// Returns the real accent swatch when accent theming is enabled, or a muted
/// surface-blended preview while the global accent switch is off.
Color resolveAccentSwatchColor({
  required Color color,
  required Color surface,
  required bool enabled,
}) {
  if (enabled) return color;
  return Color.lerp(color, surface, .62)!;
}
