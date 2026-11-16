import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/profile_deep_link_service.dart';

void main() {
  group('ProfileDeepLinkService.usernameFromLink', () {
    test('parses an ordinary HTTPS profile URL', () {
      expect(
        ProfileDeepLinkService.usernameFromLink('https://novyn.app/user/ananya'),
        'ananya',
      );
    });

    test('decodes usernames that were URL encoded in the path', () {
      expect(
        ProfileDeepLinkService.usernameFromLink(
          'https://novyn.app/user/ananya%20sonkar',
        ),
        'ananya sonkar',
      );
    });

    test('continues to accept the legacy Novyn custom scheme', () {
      expect(
        ProfileDeepLinkService.usernameFromLink('novyn://user/ananya'),
        'ananya',
      );
    });

    test('rejects profile URLs from unrelated hosts', () {
      expect(
        ProfileDeepLinkService.usernameFromLink('https://example.com/user/ananya'),
        isNull,
      );
    });

    test('rejects malformed and incomplete profile paths', () {
      expect(ProfileDeepLinkService.usernameFromLink('https://novyn.app/user/'), isNull);
      expect(ProfileDeepLinkService.usernameFromLink('https://novyn.app/chats/ananya'), isNull);
      expect(ProfileDeepLinkService.usernameFromLink('not a URL'), isNull);
    });
  });
}
