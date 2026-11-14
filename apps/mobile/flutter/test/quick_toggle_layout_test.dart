import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/screens/profile/settings/quick_toggle_layout.dart';

void main() {
  group('Adaptive Settings Quick Toggle layout', () {
    test('no selected shortcuts produces an empty layout', () {
      expect(
        quickToggleLayoutModeFor(0),
        QuickToggleLayoutMode.empty,
      );
    });

    test('one selected shortcut expands full width with its label', () {
      expect(
        quickToggleLayoutModeFor(1),
        QuickToggleLayoutMode.single,
      );
    });

    test('two selected shortcuts split into equal columns', () {
      expect(
        quickToggleLayoutModeFor(2),
        QuickToggleLayoutMode.split,
      );
    });

    test('three selected shortcuts use two compact tiles and one full row', () {
      expect(
        quickToggleLayoutModeFor(3),
        QuickToggleLayoutMode.twoPlusOne,
      );
    });

    test('four selected shortcuts use a two by two grid', () {
      expect(
        quickToggleLayoutModeFor(4),
        QuickToggleLayoutMode.grid,
      );
    });
  });
}
