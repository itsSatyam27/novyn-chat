import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/widgets/chat_link_text.dart';

void main() {
  test('extractFirstChatUrl ignores trailing sentence punctuation', () {
    expect(
      extractFirstChatUrl('Take a look: https://example.com/novyn.'),
      'https://example.com/novyn',
    );
    expect(
      extractFirstChatUrl('Read (https://example.com/page?id=1).'),
      'https://example.com/page?id=1',
    );
  });

  test('extractFirstChatUrl ignores non-web and credential URLs', () {
    expect(extractFirstChatUrl('javascript:alert(1)'), isNull);
    expect(extractFirstChatUrl('https://user:pass@example.com/'), isNull);
    expect(extractFirstChatUrl('No URL in this message'), isNull);
  });

  testWidgets('renders links as tappable inline message text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatLinkText(
            text: 'Open https://example.com/novyn now.',
            style: const TextStyle(fontSize: 15),
          ),
        ),
      ),
    );

    expect(find.text('https://example.com/novyn'), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget);
  });
}
