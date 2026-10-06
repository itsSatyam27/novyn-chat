import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/widgets/chat_widgets.dart';
import 'package:novyn/services/firebase_configuration.dart';

void main() {
  testWidgets('GlassContainer renders its content and configured shape', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: GlassContainer(
        borderRadius: 16,
        padding: 8,
        child: Text('Novyn conversation'),
      )),
    ));
    expect(find.text('Novyn conversation'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clip.borderRadius, BorderRadius.circular(16));
    expect(tester.takeException(), isNull);
  });

  test('Android uses its registration in the same project as Novyn web', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final options = FirebaseConfiguration.options!;
    expect(options.projectId, FirebaseConfiguration.web.projectId);
    expect(options.messagingSenderId, FirebaseConfiguration.web.messagingSenderId);
    expect(options.storageBucket, FirebaseConfiguration.web.storageBucket);
    expect(options.appId, contains(':android:'));
    expect(options.appId, isNot(FirebaseConfiguration.web.appId));
    expect(options.apiKey, isNotEmpty);
  });

  test('Missing desktop Firebase registration produces an actionable error', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(() => FirebaseConfiguration.options, throwsStateError);
  });
}
