import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/rtc_ice_configuration.dart';

void main() {
  group('RtcIceConfiguration.normalizeServers', () {
    test('normalizes single and multiple valid STUN/TURN URLs', () {
      final servers = RtcIceConfiguration.normalizeServers([
        {'urls': ' stun:stun.example.com:3478 '},
        {
          'urls': [
            'turn:turn.example.com:3478',
            'turns:turn.example.com:5349?transport=tcp',
            'https://not-an-ice-server.example.com',
          ],
          'username': ' turn-user ',
          'credential': 'turn-secret',
          'credentialType': 'password',
        },
      ]);

      expect(servers, hasLength(2));
      expect(servers[0]['urls'], 'stun:stun.example.com:3478');
      expect(servers[1]['urls'], [
        'turn:turn.example.com:3478',
        'turns:turn.example.com:5349?transport=tcp',
      ]);
      expect(servers[1]['username'], 'turn-user');
      expect(servers[1]['credential'], 'turn-secret');
    });

    test('drops invalid entries, duplicate URLs and unsupported schemes', () {
      final servers = RtcIceConfiguration.normalizeServers([
        {'urls': 'https://example.com'},
        {'urls': ''},
        {'urls': ['stun:valid.example.com', 'stun:valid.example.com']},
        'not a map',
      ]);

      expect(servers, hasLength(1));
      expect(servers.single['urls'], 'stun:valid.example.com');
    });

    test('does not retain TURN credentials from unauthenticated responses', () {
      final servers = RtcIceConfiguration.normalizeServers(
        [
          {
            'urls': 'turn:turn.example.com:3478',
            'username': 'leaked-user',
            'credential': 'leaked-secret',
          },
        ],
        allowCredentials: false,
      );

      expect(servers, [
        {'urls': 'turn:turn.example.com:3478'},
      ]);
    });
  });

  group('RtcIceConfiguration.resolve', () {
    const fallback = <Map<String, dynamic>>[
      {'urls': 'stun:stun.local-fallback.example.com:3478'},
    ];

    test('uses backend TURN configuration only for an authenticated session', () {
      final resolved = RtcIceConfiguration.resolve(
        {
          'authenticated': true,
          'iceServers': [
            {
              'urls': 'turns:turn.backend.example.com:443?transport=tcp',
              'username': 'short-lived-user',
              'credential': 'short-lived-secret',
            },
          ],
        },
        fallbackServers: fallback,
      );

      final servers = resolved['iceServers'] as List<Map<String, dynamic>>;
      expect(servers, hasLength(1));
      expect(servers.single['username'], 'short-lived-user');
      expect(servers.single['credential'], 'short-lived-secret');
      expect(resolved['iceCandidatePoolSize'], 2);
    });

    test('uses fallback servers for unauthenticated or invalid backend payloads', () {
      final unauthenticated = RtcIceConfiguration.resolve(
        {
          'authenticated': false,
          'iceServers': [
            {
              'urls': 'turn:turn.backend.example.com:3478',
              'username': 'untrusted-user',
              'credential': 'untrusted-secret',
            },
          ],
        },
        fallbackServers: fallback,
      );
      final invalid = RtcIceConfiguration.resolve(
        {'authenticated': true, 'iceServers': [{'urls': 'https://invalid.example.com'}]},
        fallbackServers: fallback,
      );

      expect(unauthenticated['iceServers'], fallback);
      expect(invalid['iceServers'], fallback);
    });
  });
}
