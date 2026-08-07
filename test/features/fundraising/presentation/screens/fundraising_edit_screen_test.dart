import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_edit_screen.dart';
import 'package:furtail_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('opening existing TREATMENT campaign preselects it once', (
    tester,
  ) async {
    await _pumpEditScreen(tester, _campaign(category: 'TREATMENT'));

    await tester.tap(find.text('Fundraising'));
    await tester.pumpAndSettle();

    final dropdown = _categoryDropdown(tester);
    expect(dropdown.initialValue, 'TREATMENT');
    expect(find.text('Treatment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy category casing is normalized without duplicates', (
    tester,
  ) async {
    await _pumpEditScreen(tester, _campaign(category: ' treatment '));

    await tester.tap(find.text('Fundraising'));
    await tester.pumpAndSettle();

    final dropdown = _categoryDropdown(tester);
    expect(dropdown.initialValue, 'TREATMENT');
    expect(find.text('Treatment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown legacy category remains selectable and safe', (
    tester,
  ) async {
    await _pumpEditScreen(tester, _campaign(category: 'SURGERY_SUPPORT'));

    await tester.tap(find.text('Fundraising'));
    await tester.pumpAndSettle();

    final dropdown = _categoryDropdown(tester);
    expect(dropdown.initialValue, 'SURGERY_SUPPORT');
    expect(find.text('Legacy category: SURGERY_SUPPORT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpEditScreen(
  WidgetTester tester,
  FundraisingCampaign campaign,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FundraisingEditScreen(campaign: campaign),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DropdownButtonFormField<String> _categoryDropdown(WidgetTester tester) {
  return tester.widget<DropdownButtonFormField<String>>(
    find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Category',
    ),
  );
}

FundraisingCampaign _campaign({required String category}) {
  return FundraisingCampaign(
    id: 42,
    postId: 142,
    title: 'Help Tuni recover',
    targetAmount: 100000,
    targetAmountMinor: 100000,
    monthlyGoalMinor: null,
    fundingMode: 'ONE_TIME',
    startsAt: DateTime(2026, 7, 1),
    endsAt: DateTime(2026, 8, 1),
    deadline: DateTime(2026, 8, 1),
    nextReviewAt: null,
    publishedAt: DateTime(2026, 7, 10),
    createdAt: DateTime(2026, 7, 10),
    status: 'ACTIVE',
    author: const FundraisingAuthor(id: 7, displayName: 'Owner'),
    caption: 'Treatment support',
    media: const <FundraisingMediaItem>[],
    stats: const FundraisingStats(
      raisedAmount: 25000,
      withdrawnAmount: 0,
      donorsCount: 4,
    ),
    isAccountVerified: true,
    category: category,
    locationText: 'Dhaka',
    last3Donors: const <FundraisingDonor>[],
  );
}
