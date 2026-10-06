import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/widgets/user_avatar.dart';
import 'package:novyn/services/backend_contacts.dart';

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
}
