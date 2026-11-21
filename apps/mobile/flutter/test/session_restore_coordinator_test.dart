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

  group('SessionRejectionTracker', () {
    test('does not treat a rapid 401 burst as independent rejections', () {
      final tracker = SessionRejectionTracker();
      final start = DateTime(2026, 11, 21, 12);

      expect(tracker.record(start), isFalse);
      expect(tracker.count, 1);
      expect(tracker.record(start.add(const Duration(seconds: 1))), isFalse);
      expect(tracker.record(start.add(const Duration(seconds: 10))), isFalse);
      expect(tracker.count, 1);
    });

    test('invalidates only after three spaced definitive rejections', () {
      final tracker = SessionRejectionTracker();
      final start = DateTime(2026, 11, 21, 12);

      expect(tracker.record(start), isFalse);
      expect(tracker.record(start.add(const Duration(seconds: 29))), isFalse);
      expect(tracker.count, 1);
      expect(tracker.record(start.add(const Duration(seconds: 30))), isFalse);
      expect(tracker.count, 2);
      expect(tracker.record(start.add(const Duration(seconds: 60))), isTrue);
      expect(tracker.count, 3);
    });

    test('a verified session resets previous rejection history', () {
      final tracker = SessionRejectionTracker();
      final start = DateTime(2026, 11, 21, 12);

      tracker.record(start);
      tracker.record(start.add(const Duration(seconds: 30)));
      tracker.reset();

      expect(tracker.count, 0);
      expect(tracker.record(start.add(const Duration(seconds: 31))), isFalse);
      expect(tracker.count, 1);
    });
  });
}
