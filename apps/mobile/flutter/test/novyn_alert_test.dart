import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/widgets/novyn_alert.dart';

void main() {
  tearDown(NovynAlert.hide);

  Future<void> pumpAlertHost(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
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
  }

  testWidgets('default Snackbar appears at the bottom with message details', (tester) async {
    await pumpAlertHost(tester);
    await tester.tap(find.text('Show alert'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.textContaining('Profile saved'), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining('Profile saved')).dy,
      greaterThan(tester.view.physicalSize.height /
          tester.view.devicePixelRatio * .35),
    );
  });

  testWidgets('all six Alert Lab styles render the saved alert event', (tester) async {
    await pumpAlertHost(tester);
    const styles = [
      'snackbar',
      'top_banner',
      'capsule',
      'switch_card',
      'centre_hud',
      'countdown_card',
    ];

    for (final style in styles) {
      NovynAlert.preview(
        tester.element(find.text('Show alert')),
        style,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Profile saved'), findsOneWidget,
          reason: 'Expected $style to display the alert');
      NovynAlert.hide();
      await tester.pump();
    }
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
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.textContaining('Text copied'), findsOneWidget);
    expect(find.textContaining('Message pinned'), findsNothing);
  });


  testWidgets('legacy SnackBar API renders through Novyn styles and keeps actions', (tester) async {
    var undoCalled = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showNovynAlert(SnackBar(
                  content: const Text('Message removed'),
                  duration: const Duration(seconds: 8),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => undoCalled = true,
                  ),
                ));
              },
              child: const Text('Show legacy alert'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Show legacy alert'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Message removed'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(undoCalled, isTrue);
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
    await tester.pump(const Duration(milliseconds: 450));
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(actionCalled, isTrue);
  });
}
