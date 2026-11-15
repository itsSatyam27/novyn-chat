import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/backend_contacts.dart';
import 'package:novyn/utils/presence_utils.dart';

void main() {
  group('formatLastSeenLabel', () {
    final now = DateTime(2026, 11, 15, 12);
    test('does not invent a timestamp when last seen is unavailable', () {
      expect(formatLastSeenLabel(null, now: now), 'Offline');
    });
    test('formats recent timestamps', () {
      expect(formatLastSeenLabel(now.subtract(const Duration(minutes: 5)), now: now), 'Last seen 5m ago');
    });
    test('uses yesterday for the previous calendar day', () {
      expect(formatLastSeenLabel(DateTime(2026, 11, 14, 10), now: now), 'Last seen yesterday');
    });
    test('uses a calendar date for older timestamps', () {
      expect(formatLastSeenLabel(DateTime(2026, 11, 1, 10), now: now), 'Last seen 1 Nov');
    });
  });

  test('live presence events carry and clear last-seen timestamps', () {
    final contacts = BackendContacts();
    final offlineAt = DateTime.parse('2026-11-14T18:30:00.000Z');
    contacts.applyEvent('friend_list_updated', {'friends': [{
      'username':'harsh','online':false,'presence':'offline',
      'lastSeenAt':offlineAt.toIso8601String(),
    }]});
    expect(contacts.friends.single.lastSeen, offlineAt);
    final latest = DateTime.parse('2026-11-15T09:00:00.000Z');
    contacts.applyEvent('user_status', {
      'username':'harsh','online':false,'presence':'offline',
      'lastSeenAt':latest.toIso8601String(),
    });
    expect(contacts.friends.single.lastSeen, latest);
    // A null field is an explicit server-side privacy/visibility decision.
    contacts.applyEvent('user_status', {
      'username':'harsh','online':true,'presence':'online','lastSeenAt':null,
    });
    expect(contacts.friends.single.lastSeen, isNull);
    contacts.dispose();
  });
}
