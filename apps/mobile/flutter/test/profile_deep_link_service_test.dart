import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/profile_deep_link_service.dart';

void main() {
  group('ProfileDeepLinkService.usernameFromLink', () {
    test('parses a Novyn in-app profile link', () {
      expect(
        ProfileDeepLinkService.usernameFromLink('novyn://user/ananya'),
        'ananya',
      );
    });

    test('decodes usernames that were URL encoded in the path', () {
      expect(
        ProfileDeepLinkService.usernameFromLink(
          'novyn://user/ananya%20sonkar',
        ),
        'ananya sonkar',
      );
    });

    test('accepts Novyn custom-scheme profile links', {
      expect(
        ProfileDeepLinkService.usernameFromLink('novyn://user/ananya'),
        'ananya',
      );
    });

    test('rejects website URLs because no public profile domain is configured', () {
      expect(
        ProfileDeepLinkService.usernameFromLink('https://example.com/user/ananya'),
        isNull,
      );
      expect(
        ProfileDeepLinkService.usernameFromLink('https://novyn.app/user/ananya'),
        isNull,
      );
    });

    test('rejects malformed and incomplete profile paths', () {
      expect(ProfileDeepLinkService.usernameFromLink('novyn://user/'), isNull);
      expect(ProfileDeepLinkService.usernameFromLink('novyn://chats/ananya'), isNull);
      expect(ProfileDeepLinkService.usernameFromLink('not a URL'), isNull);
    });
  });
}
