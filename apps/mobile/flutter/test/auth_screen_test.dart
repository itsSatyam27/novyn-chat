import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/screens/auth_screen.dart';

void main() {
  testWidgets('shows the new auth flow without Google login', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AuthScreen(onAuthenticated: (_) {})));
    expect(find.text('Your people,\nyour space.'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Google'), findsNothing);
    await tester.tap(find.text('Create account').first);
    await tester.pumpAndSettle();
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
  });
}
