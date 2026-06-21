import 'package:bpa_app/features/campaign/presentation/widgets/campaign_state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CampaignErrorView shows retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignErrorView(
            message: 'Network error',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Network error'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('CampaignEmptyView shows title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CampaignEmptyView(title: 'No campaigns'),
        ),
      ),
    );
    expect(find.text('No campaigns'), findsOneWidget);
  });
}
