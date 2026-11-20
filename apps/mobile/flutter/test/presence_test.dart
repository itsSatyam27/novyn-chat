import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novyn/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AuthService> createAuth(Future<void> Function(String) save) async {
    // AuthService restores the non-secret identity mirror before checking
    // the secure session. Seed it so this unit test does not depend on a
    // platform FlutterSecureStorage plugin being registered in CI.
    SharedPreferences.setMockInitialValues({
      'novyn_explicit_signed_out_v1': false,
      'novyn_last_signed_in_identity_mirror_v1': jsonEncode({
        'username': 'presence_test',
        'displayName': 'presence_test',
        'email': '',
        'presenceMode': 'online',
      }),
    });

    final auth = AuthService(
      savePresence: save,
      restoreSession: () async => {
        'authenticated': true,
        'username': 'presence_test',
        'presenceMode': 'online',
      },
    );

    if (!auth.authReady || auth.user == null) {
      final restored = Completer<void>();
      void listen() {
        if (auth.authReady && auth.user != null && !restored.isCompleted) {
          restored.complete();
        }
      }
      auth.addListener(listen);
      listen();
      await restored.future.timeout(const Duration(seconds: 10));
      auth.removeListener(listen);
    }
    return auth;
  }

  test('canonical status waits for confirmation and rolls back failed saves', () async {
    final confirmation = Completer<void>();
    final requestStarted = Completer<void>();
    String? sent;
    final auth = await createAuth((mode) {
      sent = mode;
      if (!requestStarted.isCompleted) requestStarted.complete();
      return confirmation.future;
    });
    final saving = auth.updateStatus('Away');
    await requestStarted.future;
    expect(sent, 'away');
    expect(auth.user!.presenceMode, 'away');
    expect(auth.updatingPresence, isTrue);
    final failed = expectLater(saving, throwsStateError);
    confirmation.completeError(StateError('disconnected'));
    await failed;
    expect(auth.user!.presenceMode, 'online');
    expect(auth.updatingPresence, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('novyn_notification_presence_mode'), 'online');
    auth.dispose();
  });


  test('Offline alias saves the supported Invisible presence mode', () async {
    String? sent;
    final auth = await createAuth((mode) async {
      sent = mode;
    });

    await auth.updateStatus('Offline');

    expect(sent, 'invisible');
    expect(auth.user!.presenceMode, 'invisible');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('novyn_notification_presence_mode'), 'invisible');
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
