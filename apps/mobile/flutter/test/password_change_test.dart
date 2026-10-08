import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AuthService> createAuth({
    Future<void> Function(String, String)? save,
    bool signedIn = true,
  }) async {
    final auth = AuthService(
      savePassword: save,
      restoreSession: () async => signedIn
          ? {'authenticated': true, 'username': 'password_test'}
          : null,
    );
    await Future<void>.delayed(Duration.zero);
    addTearDown(auth.dispose);
    return auth;
  }

  test('password change reports success only after server confirmation', () async {
    final confirmation = Completer<void>();
    final auth = await createAuth(save: (current, next) {
      expect(current, 'current-secret');
      expect(next, 'new-password-123');
      return confirmation.future;
    });
    var completed = false;
    final result = auth.changePassword('current-secret', 'new-password-123')
      ..then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    confirmation.complete();
    expect(await result, isNull);
  });

  test('server rejection reaches the user without reporting success', () async {
    final auth = await createAuth(save: (_, __) async {
      throw StateError('Incorrect current password.');
    });
    expect(await auth.changePassword('wrong-password', 'new-password-123'),
        'Incorrect current password.');
  });

  test('invalid inputs never reach the password transport', () async {
    var calls = 0;
    final auth = await createAuth(save: (_, __) async { calls++; });
    expect(await auth.changePassword('', 'new-password-123'), isNotNull);
    expect(await auth.changePassword('current-secret', 'short'),
        contains('12 characters'));
    expect(calls, 0);
  });

  test('signed-out or unavailable service cannot claim success', () async {
    var calls = 0;
    final signedOut = await createAuth(signedIn: false,
        save: (_, __) async { calls++; });
    expect(await signedOut.changePassword('current', 'new-password-123'),
        contains('sign in'));
    expect(calls, 0);
    final unavailable = await createAuth();
    expect(await unavailable.changePassword('current', 'new-password-123'),
        contains('unavailable'));
  });
}
