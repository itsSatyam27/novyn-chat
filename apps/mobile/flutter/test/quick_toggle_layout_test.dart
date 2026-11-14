import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/screens/profile/settings/quick_toggle_layout.dart';

void main() {
  group('Settings quick toggle layout', () {
    test('one selected toggle uses a single full-width row', () {
      expect(arrangeQuickToggleRows(['lock']), equals([['lock']]));
    });

    test('two selected toggles share one row', () {
      expect(arrangeQuickToggleRows(['lock', 'dnd']), equals([['lock', 'dnd']]));
    });

    test('three selected toggles use two compact and one full-width row', () {
      expect(
        arrangeQuickToggleRows(['lock', 'dnd', 'sounds']),
        equals([
          ['lock', 'dnd'],
          ['sounds'],
        ]),
      );
    });

    test('four selected toggles use a two by two grid', () {
      expect(
        arrangeQuickToggleRows(['lock', 'dnd', 'sounds', 'vibration']),
        equals([
          ['lock', 'dnd'],
          ['sounds', 'vibration'],
        ]),
      );
    });

    test('empty selection renders no rows', () {
      expect(arrangeQuickToggleRows<String>([]), isEmpty);
    });
  });
}
