import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_status_views.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size surfaceSize = const Size(320, 700),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: widget!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('FundraisingRequirementRow', () {
    testWidgets('lays out vertically with no overflow at 320dp', (
      tester,
    ) async {
      await _pump(
        tester,
        FundraisingRequirementRow(
          icon: Icons.badge_outlined,
          title: 'Fundraising profile',
          description:
              'Add address and identity details before creating a fundraiser.',
          state: FundraisingRequirementState.incomplete,
          actionLabel: 'Complete',
          onAction: () {},
        ),
        surfaceSize: const Size(320, 700),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Fundraising profile'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);
    });

    testWidgets('supports 1.3x text scale at 320dp with no overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        FundraisingRequirementRow(
          icon: Icons.description_outlined,
          title: 'Verification documents',
          description:
              'Reviewers need your required documents before they can approve campaigns.',
          state: FundraisingRequirementState.incomplete,
          actionLabel: 'Upload',
          onAction: () {},
        ),
        surfaceSize: const Size(320, 900),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('action button meets the 48dp minimum touch target', (
      tester,
    ) async {
      await _pump(
        tester,
        FundraisingRequirementRow(
          icon: Icons.badge_outlined,
          title: 'Fundraising profile',
          description: 'Short description.',
          state: FundraisingRequirementState.completed,
          actionLabel: 'Edit',
          onAction: () {},
        ),
      );

      final buttonSize = tester.getSize(
        find.widgetWithText(OutlinedButton, 'Edit'),
      );
      expect(buttonSize.height, greaterThanOrEqualTo(48));
    });

    testWidgets('uses a wide row layout at 500dp without overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        FundraisingRequirementRow(
          icon: Icons.badge_outlined,
          title: 'Fundraising profile',
          description:
              'Add address and identity details before creating a fundraiser.',
          state: FundraisingRequirementState.incomplete,
          actionLabel: 'Complete',
          onAction: () {},
        ),
        surfaceSize: const Size(500, 700),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Fundraising profile'), findsOneWidget);
    });
  });
}
