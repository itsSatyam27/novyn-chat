import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/screens/welcome_screen.dart';
import 'package:novyn/services/auth_api.dart';

void main() {
  testWidgets('Continue stays on the new Phase 2 flow, not a legacy chat screen', (tester) async {
    const account = NovynAccount(username: 'satya', displayName: 'Satyam', email: 'satya@example.com');
    var continued = false;
    await tester.pumpWidget(MaterialApp(
      home: WelcomeScreen(account: account, onContinue: () => continued = true, onSignOut: () {}),
    ));
    expect(find.text('WELCOME TO NOVYN'), findsOneWidget);
    expect(find.text('You’re in.'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(continued, isTrue);
    expect(find.text('Chats'), findsNothing);
  });
}
