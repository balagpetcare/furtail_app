import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:furtail_app/main.dart';

void main() {
  testWidgets('App builds MaterialApp root without crashing',
      (WidgetTester tester) async {
    // Provide an empty (unauthenticated) SharedPreferences store so the app
    // does not try to resume a session.
    SharedPreferences.setMockInitialValues({});

    // FurtailApp is a ConsumerStatefulWidget — must be wrapped in ProviderScope.
    await tester.pumpWidget(const ProviderScope(child: FurtailApp()));

    // Advance fake time far enough to drain timers scheduled by background
    // service initialisation (deepLinkServiceProvider, PostUploadManager, etc.).
    // Services that use platform channels (Firebase, AppLinks) handle their own
    // errors via try/catch; advancing fake time clears the pending timer queue.
    await tester.pump(const Duration(hours: 1));

    // Verify the widget tree was built successfully.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
