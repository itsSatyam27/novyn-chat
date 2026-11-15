/// Validation and selection for backend-managed WebRTC ICE server lists.
///
/// TURN credentials are accepted only when the backend confirms that the
/// response belongs to an authenticated session. Invalid URLs are discarded.
class RtcIceConfiguration {
  RtcIceConfiguration._();

  static final RegExp _supportedUrl =
      RegExp(r'^(stun|stuns|turn|turns):', caseSensitive: false);

  static List<Map<String, dynamic>> normalizeServers(
    dynamic value, {
    bool allowCredentials = true,
  }) {
    if (value is! List) return <Map<String, dynamic>>[];

    final normalized = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final rawEntry in value) {
      if (rawEntry is! Map) continue;
      final rawUrls = rawEntry['urls'];
      final candidates = rawUrls is List ? rawUrls : <dynamic>[rawUrls];
      final urls = <String>[];

      for (final candidate in candidates) {
        if (candidate is! String) continue;
        final url = candidate.trim();
        if (url.isEmpty || url.length > 2048 || !_supportedUrl.hasMatch(url)) {
          continue;
        }
        if (!urls.contains(url)) urls.add(url);
      }
      if (urls.isEmpty) continue;

      final entry = <String, dynamic>{
        'urls': urls.length == 1 ? urls.first : urls,
      };
      if (allowCredentials) {
        final username = rawEntry['username'];
        if (username is String && username.trim().isNotEmpty) {
          entry['username'] = username.trim();
        }
        final credential = rawEntry['credential'];
        if (credential is String && credential.isNotEmpty) {
          entry['credential'] = credential;
        }
        final credentialType = rawEntry['credentialType'];
        if (credentialType is String && credentialType.trim().isNotEmpty) {
          entry['credentialType'] = credentialType.trim();
        }
      }

      final signature = urls.join('|') + '|' +
          (entry['username'] ?? '').toString() + '|' +
          (entry['credential'] ?? '').toString() + '|' +
          (entry['credentialType'] ?? '').toString();
      if (seen.add(signature)) normalized.add(entry);
    }

    return normalized;
  }

  /// Prefer a valid authenticated backend response; otherwise keep the
  /// pre-existing local fallback so calls still work during API outages.
  static Map<String, dynamic> resolve(
    dynamic payload, {
    required List<Map<String, dynamic>> fallbackServers,
  }) {
    final body = payload is Map ? payload : const <String, dynamic>{};
    final authenticated = body['authenticated'] == true;
    final dynamicServers = normalizeServers(
      body['iceServers'],
      allowCredentials: authenticated,
    );
    final fallback = normalizeServers(fallbackServers);
    final selected = authenticated && dynamicServers.isNotEmpty
        ? dynamicServers
        : fallback;

    return <String, dynamic>{
      'iceServers': selected,
      'iceCandidatePoolSize': 2,
    };
  }
}
