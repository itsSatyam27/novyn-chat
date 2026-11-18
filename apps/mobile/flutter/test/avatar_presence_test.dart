import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/widgets/user_avatar.dart';
import 'package:novyn/services/backend_contacts.dart';
import 'package:novyn/utils/presence_utils.dart';

void main() {
  testWidgets('avatar dot follows each status and disconnection',
      (tester) async {
    for (final entry in {
      'online': const Color(0xFF10B981),
      'away': const Color(0xFFF59E0B),
      'busy': const Color(0xFFEC4899),
      'invisible': const Color(0xFF64748B),
      'offline': const Color(0xFF64748B),
    }.entries) {
      await tester.pumpWidget(MaterialApp(
          home: Center(
              child: UserAvatar(
        name: 'Harsh',
        photoUrl: '',
        showOnlineIndicator: true,
        isOnline: entry.key != 'offline',
        presence: entry.key,
      ))));
      final dot = tester
          .widget<Container>(find.byKey(const ValueKey('avatar-presence')));
      expect((dot.decoration as BoxDecoration).color, entry.value);
    }
  });

  test('live presence events preserve full status in the contacts cache', () {
    final contacts = BackendContacts();
    contacts.applyEvent('friend_list_updated', {
      'friends': [
        {'username': 'harsh', 'online': true, 'presence': 'online'},
      ]
    });
    contacts.applyEvent('user_status',
        {'username': 'harsh', 'online': true, 'presence': 'busy'});
    expect(contacts.friends.single.status, 'busy');
    // The older boolean callback must not discard the richer status event.
    contacts.updateStatus('harsh', true);
    expect(contacts.friends.single.status, 'busy');
    contacts.applyEvent('user_status',
        {'username': 'harsh', 'online': false, 'presence': 'offline'});
    expect(contacts.friends.single.isOnline, false);
    expect(contacts.friends.single.status, 'offline');
    contacts.dispose();
  });

  group('presenceStatusColor', () {
    test('returns emerald for online', () {
      expect(presenceStatusColor('online'), const Color(0xFF10B981));
    });
    test('returns amber for away', () {
      expect(presenceStatusColor('away'), const Color(0xFFF59E0B));
    });
    test('returns rose for busy', () {
      expect(presenceStatusColor('busy'), const Color(0xFFEC4899));
    });
    test('returns violet for invisible', () {
      expect(presenceStatusColor('invisible'), const Color(0xFF8B5CF6));
    });
    test('returns slate for offline', () {
      expect(presenceStatusColor('offline'), const Color(0xFF94A3B8));
    });
    test('returns slate when isOnline is false regardless of status', () {
      expect(presenceStatusColor('online', isOnline: false),
          const Color(0xFF94A3B8));
    });
    test('defaults to online color for null status', () {
      expect(presenceStatusColor(null), const Color(0xFF10B981));
    });
  });

  testWidgets('PresenceIndicatorBar renders correctly for each status',
      (tester) async {
    for (final status in ['online', 'away', 'busy', 'invisible', 'offline']) {
      final isOnline = status != 'offline';
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: PresenceIndicatorBar(isOnline: isOnline, status: status),
        ),
      ));
      final bar = tester.widget<Container>(
          find.byKey(const ValueKey('presence-indicator-bar')));
      final decoration = bar.decoration as BoxDecoration;
      final expectedColor = presenceStatusColor(status, isOnline: isOnline);
      if (!isOnline || status == 'offline') {
        // Offline bars are faded
        expect(decoration.color, expectedColor.withValues(alpha: 0.38));
        expect(decoration.boxShadow, isNull);
      } else {
        expect(decoration.color, expectedColor);
        expect(decoration.boxShadow, isNotNull);
      }
    }
  });
}
