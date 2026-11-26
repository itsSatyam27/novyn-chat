import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/screens/calls/group_call_layout.dart';

void main() {
  group('GroupCallGridSpec', () {
    test('uses a single full-width tile for one participant', () {
      expect(
        GroupCallGridSpec.columnsFor(
          participantCount: 1,
          width: 360,
          height: 720,
        ),
        1,
      );
    });

    test('stacks two participants on a narrow portrait phone', () {
      expect(
        GroupCallGridSpec.columnsFor(
          participantCount: 2,
          width: 360,
          height: 760,
        ),
        1,
      );
    });

    test('uses a side-by-side pair on a landscape phone', () {
      expect(
        GroupCallGridSpec.columnsFor(
          participantCount: 2,
          width: 740,
          height: 340,
        ),
        2,
      );
    });

    test('uses a compact single row for four people in landscape', () {
      expect(
        GroupCallGridSpec.columnsFor(
          participantCount: 4,
          width: 800,
          height: 360,
        ),
        4,
      );
    });

    test('uses a balanced two-column grid for portrait groups', () {
      expect(
        GroupCallGridSpec.columnsFor(
          participantCount: 4,
          width: 390,
          height: 760,
        ),
        2,
      );
    });

    test('keeps tile aspect ratio within readable bounds', () {
      final ratio = GroupCallGridSpec.aspectRatioFor(
        participantCount: 4,
        columns: 2,
        width: 390,
        height: 420,
      );
      expect(ratio, greaterThanOrEqualTo(.55));
    });

    test('avoids invalid dimensions on very small surfaces', () {
      final ratio = GroupCallGridSpec.aspectRatioFor(
        participantCount: 4,
        columns: 2,
        width: 120,
        height: 100,
      );
      expect(ratio, isFinite);
      expect(ratio, greaterThanOrEqualTo(.55));
    });
  });
}
