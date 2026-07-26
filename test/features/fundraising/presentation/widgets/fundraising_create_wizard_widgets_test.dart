import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_draft_models.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_campaign_preview_card.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_create_wizard_widgets.dart';
import 'package:furtail_app/features/media/composer/media_draft_item.dart';
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
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('FundraisingWizardProgressHeader', () {
    testWidgets('shows the first step in the corrected 3-step flow', (
      tester,
    ) async {
      await _pump(
        tester,
        FundraisingWizardProgressHeader(
          currentStep: FundraisingWizardStep.fundraiserType,
          completedSteps: const <FundraisingWizardStep>{},
          onStepTapped: (_) {},
        ),
      );

      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.text('Fundraiser details'), findsOneWidget);
      expect(find.text('Payout'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('does not truncate the current-step title at 1.3x scale', (
      tester,
    ) async {
      await _pump(
        tester,
        FundraisingWizardProgressHeader(
          currentStep: FundraisingWizardStep.fundraiserType,
          completedSteps: const <FundraisingWizardStep>{},
          onStepTapped: (_) {},
        ),
        surfaceSize: const Size(320, 700),
        textScale: 1.3,
      );

      final textWidget = tester.widget<Text>(find.text('Fundraiser details'));
      expect(textWidget.overflow, isNot(TextOverflow.ellipsis));
    });

    testWidgets('never exposes a payout step in the visible flow', (
      tester,
    ) async {
      await _pump(
        tester,
        FundraisingWizardProgressHeader(
          currentStep: FundraisingWizardStep.preview,
          completedSteps: const <FundraisingWizardStep>{
            FundraisingWizardStep.fundraiserType,
            FundraisingWizardStep.location,
          },
          onStepTapped: (_) {},
        ),
      );

      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('Payout'), findsNothing);
    });
  });

  group('FundraisingWizardBottomBar', () {
    testWidgets('shows Cancel and hides Save Draft on the first visible step', (
      tester,
    ) async {
      await _pump(
        tester,
        FundraisingWizardBottomBar(
          canGoBack: false,
          onBack: () {},
          onCancel: () {},
          onSaveDraft: () {},
          onContinue: () {},
          continueLabel: 'Continue',
          showSaveDraft: false,
          continueEnabled: false,
          helperText: 'Complete the required items to continue.',
        ),
      );

      expect(find.text('Save draft'), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Back'), findsNothing);
      expect(
        find.text('Complete the required items to continue.'),
        findsOneWidget,
      );
    });

    testWidgets('keeps the continue action readable at 320dp and 1.3x scale', (
      tester,
    ) async {
      await _pump(
        tester,
        FundraisingWizardBottomBar(
          canGoBack: false,
          onBack: () {},
          onCancel: () {},
          onSaveDraft: () {},
          onContinue: () {},
          continueLabel: 'Continue to fundraiser',
          showSaveDraft: true,
          continueEnabled: true,
        ),
        surfaceSize: const Size(320, 700),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Continue to fundraiser'), findsOneWidget);
      final buttonSize = tester.getSize(
        find.widgetWithText(FilledButton, 'Continue to fundraiser'),
      );
      expect(buttonSize.height, greaterThanOrEqualTo(56));
    });
  });

  group('FundraisingSectionCard', () {
    testWidgets('lays out wrapped fields without overflow at 320dp', (
      tester,
    ) async {
      final titleController = TextEditingController();
      final amountController = TextEditingController();
      addTearDown(titleController.dispose);
      addTearDown(amountController.dispose);

      await _pump(
        tester,
        FundraisingSectionCard(
          title: 'Story & goal',
          subtitle: 'Explain the story clearly and set a realistic target.',
          child: Column(
            children: [
              FundraisingTextField(
                controller: titleController,
                labelText: 'Campaign title',
              ),
              const SizedBox(height: 14),
              FundraisingAmountField(
                controller: amountController,
                labelText: 'Target amount (BDT)',
              ),
            ],
          ),
        ),
        surfaceSize: const Size(320, 700),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Campaign title'), findsOneWidget);
      expect(find.text('Target amount (BDT)'), findsOneWidget);
    });
  });

  group('FundraisingCampaignPreviewCard', () {
    testWidgets('shows one-time targets and dates', (tester) async {
      await _pump(
        tester,
        FundraisingCampaignPreviewCard(
          draft: FundraisingDraftRecovery(
            title: 'Help Tuni recover',
            story: 'This is a long enough story to render the preview card.',
            category: 'TREATMENT',
            beneficiaryName: 'Tuni',
            beneficiaryType: 'PET',
            fundingMode: 'ONE_TIME',
            targetAmountMinor: 120000,
            endsAt: DateTime(2026, 9, 1),
            locationText: 'Dhaka, Bangladesh',
            expenses: const <FundraisingExpenseItem>[],
          ),
          mediaItems: const <MediaDraftItem>[],
        ),
        surfaceSize: const Size(360, 1100),
      );

      expect(find.text('One-time fundraiser'), findsOneWidget);
      expect(find.textContaining('BDT 120,000'), findsWidgets);
      expect(find.textContaining('Sep'), findsOneWidget);
    });

    testWidgets('shows ongoing support without a mandatory end date', (
      tester,
    ) async {
      await _pump(
        tester,
        FundraisingCampaignPreviewCard(
          draft: FundraisingDraftRecovery(
            title: 'Ongoing shelter support',
            story: 'This is a long enough story to render the preview card.',
            category: 'SHELTER',
            beneficiaryName: 'Shelter',
            beneficiaryType: 'ORGANIZATION',
            fundingMode: 'ONGOING',
            monthlyGoalMinor: 50000,
            locationText: 'Dhaka, Bangladesh',
            nextReviewAt: DateTime(2026, 9, 15),
            expenses: const <FundraisingExpenseItem>[],
          ),
          mediaItems: const <MediaDraftItem>[],
        ),
        surfaceSize: const Size(360, 1100),
      );

      expect(find.text('Ongoing support'), findsWidgets);
      expect(find.textContaining('BDT 50,000'), findsWidgets);
      expect(find.text('No mandatory end date.'), findsNothing);
      expect(find.text('Next review'), findsOneWidget);
    });
  });
}
