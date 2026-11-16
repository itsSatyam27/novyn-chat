import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/widgets/novyn_alert.dart';

void main() {
  testWidgets('renders a semantic top alert with title and subtitle', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => NovynAlert.showEvent(
                context,
                NovynAlertEvent.profileSaved,
                haptic: false,
              ),
              child: const Text('Show alert'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Show alert'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Profile saved'), findsOneWidget);
    expect(find.text('Your changes were saved'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Profile saved')).dy, lessThan(180));
  });

  testWidgets('replaces an active alert instead of stacking alerts', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                NovynAlert.showEvent(context, NovynAlertEvent.messagePinned, haptic: false);
                NovynAlert.showEvent(context, NovynAlertEvent.textCopied, haptic: false);
              },
              child: const Text('Show alerts'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Show alerts'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Text copied'), findsOneWidget);
    expect(find.text('Message pinned'), findsNothing);
  });

  testWidgets('supports warning alerts with an action', (tester) async {
    var actionCalled = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => NovynAlert.show(
                context,
                'Camera permission is required.',
                isError: true,
                tone: NovynAlertTone.warning,
                actionLabel: 'Settings',
                onAction: () => actionCalled = true,
                haptic: false,
              ),
              child: const Text('Show warning'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Show warning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(actionCalled, isTrue);
  });
}
