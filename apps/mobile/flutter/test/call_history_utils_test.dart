import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/utils/call_history_utils.dart';

void main() {
  group('call history utilities', () {
    test('normalizes modern and legacy video call types', () {
      for (final value in [
        'video',
        'VIDEO',
        'video_call',
        'video-call',
        'videocall',
        'video chat',
        'camera',
        '1',
        true,
      ]) {
        expect(normalizeCallType(value), 'video', reason: '$value');
      }
      for (final value in ['voice', 'audio', null, '', 'unknown']) {
        expect(normalizeCallType(value), 'voice', reason: '$value');
      }
    });

    test('uses callId as the stable call history identifier', () {
      expect(
        callLogStableId({
          'callId': 'call-123',
          'callerId': 'alice',
          'receiverId': 'bob',
        }),
        'call-123',
      );
    });

    test('creates deterministic identifiers for older records', () {
      final log = {
        'callerId': 'alice',
        'receiverId': 'bob',
        'createdAt': '2026-11-25T10:22:00.000Z',
        'type': 'video-call',
        'status': 'missed',
      };
      expect(callLogStableId(log), callLogStableId(Map.of(log)));
      expect(callLogStableId(log), contains('video'));
    });

    test('counts only missed call records not already marked as read', () {
      final logs = <Map<String, dynamic>>[
        {'callId': 'missed-1', 'status': 'missed'},
        {'callId': 'missed-2', 'status': 'missed'},
        {'callId': 'answered-1', 'status': 'incoming'},
        {'callId': 'outgoing-1', 'status': 'outgoing'},
      ];
      expect(countUnreadMissedCallLogs(logs, {'missed-1'}), 1);
      expect(
        countUnreadMissedCallLogs(logs, {'missed-1', 'missed-2'}),
        0,
      );
      expect(countUnreadMissedCallLogs(logs, {}), 2);
    });
  });
}
