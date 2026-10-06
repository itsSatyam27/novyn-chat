import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AuthService> createAuth(Future<void> Function(String) save) async {
    final auth = AuthService(
      savePresence: save,
      restoreSession: () async => {
        'authenticated': true,
        'username': 'presence_test',
        'presenceMode': 'online',
      },
    );
    await Future<void>.delayed(Duration.zero);
    return auth;
  }

  test('canonical status waits for confirmation and rolls back failed saves', () async {
    final confirmation = Completer<void>();
    String? sent;
    final auth = await createAuth((mode) {
      sent = mode;
      return confirmation.future;
    });
    final saving = auth.updateStatus('Away');
    expect(sent, 'away');
    expect(auth.user!.presenceMode, 'away');
    expect(auth.updatingPresence, isTrue);
    final failed = expectLater(saving, throwsStateError);
    confirmation.completeError(StateError('disconnected'));
    await failed;
    expect(auth.user!.presenceMode, 'online');
    expect(auth.updatingPresence, isFalse);
    auth.dispose();
  });

  test('confirmed invisible status and backend updates reach the profile', () async {
    final auth = await createAuth((_) async {});
    await auth.updateStatus('Invisible');
    expect(auth.user!.presenceMode, 'invisible');
    expect(auth.updatingPresence, isFalse);
    auth.applyProfileUpdate({'presenceMode': 'busy'});
    expect(auth.user!.presenceMode, 'busy');
    auth.dispose();
  });
}
