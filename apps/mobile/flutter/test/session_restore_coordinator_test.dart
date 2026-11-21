import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/session_restore_coordinator.dart';

void main() {
  group('SessionRestoreCoordinator', () {
    test('concurrent callers await one session restore operation', () async {
      final coordinator = SessionRestoreCoordinator();
      final gate = Completer<void>();
      var runs = 0;

      final first = coordinator.run(() async {
        runs++;
        await gate.future;
      });
      final second = coordinator.run(() async {
        runs++;
      });

      expect(identical(first, second), isTrue);
      expect(runs, 1);

      gate.complete();
      await Future.wait([first, second]);
      expect(runs, 1);

      await coordinator.run(() async {
        runs++;
      });
      expect(runs, 2);
    });

    test('a failed restore releases the coordinator for the next attempt',
        () async {
      final coordinator = SessionRestoreCoordinator();

      await expectLater(
        coordinator.run(() async {
          throw StateError('temporary session failure');
        }),
        throwsStateError,
      );

      var retried = false;
      await coordinator.run(() async {
        retried = true;
      });
      expect(retried, isTrue);
    });
  });
}
