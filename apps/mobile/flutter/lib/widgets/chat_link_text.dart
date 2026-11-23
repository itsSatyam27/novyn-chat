import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final RegExp _chatUrlPattern = RegExp(
  r"""https?://[^\s<>'"]+""",
  caseSensitive: false,
);

String _trimChatUrlPunctuation(String value) {
  var result = value;
  while (result.isNotEmpty && '.,!?;:'.contains(result[result.length - 1])) {
    result = result.substring(0, result.length - 1);
  }

  const pairs = <List<String>>[
    ['(', ')'],
    ['[', ']'],
    ['{', '}'],
  ];
  for (final pair in pairs) {
    while (result.endsWith(pair[1]) &&
        pair[0].allMatches(result).length < pair[1].allMatches(result).length) {
      result = result.substring(0, result.length - 1);
    }
  }
  return result;
}

bool _isSafeWebLink(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

/// Returns the first valid HTTP(S) link in a message, without sentence punctuation.
String? extractFirstChatUrl(String text) {
  for (final match in _chatUrlPattern.allMatches(text)) {
    final candidate = _trimChatUrlPunctuation(match.group(0) ?? '');
    if (_isSafeWebLink(candidate)) return candidate;
  }
  return null;
}

/// Renders message text normally while making any HTTP(S) URLs tappable.
class ChatLinkText extends StatelessWidget {
  const ChatLinkText({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in _chatUrlPattern.allMatches(text)) {
      final rawUrl = match.group(0) ?? '';
      final url = _trimChatUrlPunctuation(rawUrl);
      if (!_isSafeWebLink(url)) continue;

      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: InkWell(
            onTap: () => _openUrl(url),
            borderRadius: BorderRadius.circular(3),
            child: Text(
              url,
              style: style.copyWith(
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: style.color,
              ),
            ),
          ),
        ),
      );

      final punctuation = rawUrl.substring(url.length);
      if (punctuation.isNotEmpty) spans.add(TextSpan(text: punctuation));
      cursor = match.end;
    }

    if (spans.isEmpty) return Text(text, style: style);
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
    );
  }
}
