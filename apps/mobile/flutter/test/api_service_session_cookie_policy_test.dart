import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/api_service.dart';

void main() {
  group('ApiService session cookie persistence policy', () {
    test('preserves cookies after a single unauthorized response', () {
      expect(ApiService.shouldPersistSessionCookies(401), isFalse);
      expect(ApiService.shouldPersistSessionCookies(403), isFalse);
    });

    test('stores refreshed cookies on successful and non-auth responses', () {
      expect(ApiService.shouldPersistSessionCookies(200), isTrue);
      expect(ApiService.shouldPersistSessionCookies(429), isTrue);
      expect(ApiService.shouldPersistSessionCookies(503), isTrue);
    });
  });
}
