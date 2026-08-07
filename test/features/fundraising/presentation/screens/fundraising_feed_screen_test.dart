import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/features/fundraising/presentation/providers/fundraising_providers.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_feed_screen.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

Future<ProviderContainer> _pumpFeed(
  WidgetTester tester, {
  required FundraisingFeedPageLoader loader,
  bool autoLoad = true,
  VoidCallback? onOpenCreate,
  ValueChanged<int>? onOpenDetails,
  Future<bool?> Function(int campaignId)? onOpenEdit,
  VoidCallback? onOpenMyFundraisers,
  VoidCallback? onOpenMyDonations,
  VoidCallback? onOpenVerification,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FundraisingFeedScreen(
          pageLoader: loader,
          autoLoad: autoLoad,
          onOpenCreate: onOpenCreate,
          onOpenDetails: onOpenDetails,
          onOpenEdit: onOpenEdit,
          onOpenMyFundraisers: onOpenMyFundraisers,
          onOpenMyDonations: onOpenMyDonations,
          onOpenVerification: onOpenVerification,
        ),
      ),
    ),
  );
  return container;
}

FundraisingCampaign _campaign(
  int id, {
  String title = 'Campaign',
  String status = 'ACTIVE',
  String category = 'TREATMENT',
  String? location = 'Dhaka',
  DateTime? deadline,
}) {
  return FundraisingCampaign(
    id: id,
    postId: id + 100,
    title: '$title $id',
    targetAmount: 1000,
    targetAmountMinor: 1000,
    monthlyGoalMinor: null,
    fundingMode: 'ONE_TIME',
    startsAt: DateTime(2026, 7, 1),
    endsAt: deadline ?? DateTime(2026, 8, 1),
    deadline: deadline ?? DateTime(2026, 8, 1),
    nextReviewAt: null,
    publishedAt: DateTime(2026, 7, 10),
    createdAt: DateTime(2026, 7, 10),
    status: status,
    author: const FundraisingAuthor(id: 7, displayName: 'Owner'),
    caption: '#help Fundraiser details',
    media: const <FundraisingMediaItem>[],
    stats: const FundraisingStats(
      raisedAmount: 100,
      withdrawnAmount: 20,
      donorsCount: 5,
    ),
    isAccountVerified: true,
    category: category,
    locationText: location,
    last3Donors: const <FundraisingDonor>[],
  );
}

void main() {
  testWidgets('shows initial loading before first page resolves', (
    tester,
  ) async {
    final completer = Completer<FundraisingPage<FundraisingCampaign>>();

    await _pumpFeed(tester, loader: (_, _) => completer.future);
    await tester.pump();

    expect(find.text('Loading fundraisers...'), findsOneWidget);

    completer.complete(
      FundraisingPage<FundraisingCampaign>(
        items: <FundraisingCampaign>[_campaign(1)],
        nextCursor: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Campaign 1'), findsOneWidget);
  });

  testWidgets('renders multiple campaign cards from a successful page', (
    tester,
  ) async {
    await _pumpFeed(
      tester,
      loader: (_, _) async => FundraisingPage<FundraisingCampaign>(
        items: <FundraisingCampaign>[
          _campaign(1, title: 'Published'),
          _campaign(2, title: 'Rescue'),
        ],
        nextCursor: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Published 1'), findsOneWidget);
    expect(find.text('Rescue 2'), findsOneWidget);
  });

  testWidgets('renders a genuine empty state', (tester) async {
    await _pumpFeed(
      tester,
      loader: (_, _) async => const FundraisingPage<FundraisingCampaign>(
        items: [],
        nextCursor: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No public fundraisers right now'), findsOneWidget);
    expect(find.text('Create fundraiser'), findsOneWidget);
  });

  testWidgets('renders API error and retries successfully', (tester) async {
    var calls = 0;

    await _pumpFeed(
      tester,
      loader: (_, _) async {
        calls += 1;
        if (calls == 1) {
          throw Exception('network');
        }
        return FundraisingPage<FundraisingCampaign>(
          items: <FundraisingCampaign>[_campaign(1)],
          nextCursor: null,
        );
      },
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Campaign 1'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('pull-to-refresh keeps current items and reloads', (
    tester,
  ) async {
    var calls = 0;
    final first = _campaign(1, title: 'First');
    final refreshed = _campaign(2, title: 'Refreshed');

    await _pumpFeed(
      tester,
      loader: (_, _) async {
        calls += 1;
        return FundraisingPage<FundraisingCampaign>(
          items: <FundraisingCampaign>[calls == 1 ? first : refreshed],
          nextCursor: null,
        );
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('First 1'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();
    expect(find.text('First 1'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Refreshed 2'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('loads the next cursor and dedupes records', (tester) async {
    final pages = <String?, FundraisingPage<FundraisingCampaign>>{
      null: FundraisingPage<FundraisingCampaign>(
        items: <FundraisingCampaign>[_campaign(1), _campaign(2)],
        nextCursor: 'page-2',
      ),
      'page-2': FundraisingPage<FundraisingCampaign>(
        items: <FundraisingCampaign>[_campaign(2), _campaign(3)],
        nextCursor: null,
      ),
    };

    await _pumpFeed(tester, loader: (_, cursor) async => pages[cursor]!);
    await tester.pumpAndSettle();

    expect(find.text('Campaign 1'), findsOneWidget);
    expect(find.text('Campaign 2'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Campaign 2'), findsOneWidget);
    expect(find.text('Campaign 3'), findsOneWidget);
  });

  testWidgets(
    'filter state applies, clears, and persists across returning from detail',
    (tester) async {
      final seenQueries = <FundraisingFeedQuery>[];
      final container = await _pumpFeed(
        tester,
        loader: (query, _) async {
          seenQueries.add(query);
          return FundraisingPage<FundraisingCampaign>(
            items: <FundraisingCampaign>[_campaign(1)],
            nextCursor: null,
          );
        },
        onOpenDetails: (_) {},
      );
      await tester.pumpAndSettle();

      container
          .read(fundraisingFeedQueryProvider.notifier)
          .setCategory('TREATMENT');
      container.read(fundraisingFeedQueryProvider.notifier).setUrgency('HIGH');
      container
          .read(fundraisingFeedQueryProvider.notifier)
          .setView(FundraisingFeedView.myFundraisers);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('My fundraisers'), findsWidgets);
      expect(find.text('Active filters'), findsOneWidget);
      expect(find.text('Treatment'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(
        container.read(fundraisingFeedQueryProvider).category,
        'TREATMENT',
      );
      expect(
        container.read(fundraisingFeedQueryProvider).view,
        FundraisingFeedView.myFundraisers,
      );

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      final cleared = container.read(fundraisingFeedQueryProvider);
      expect(cleared.category, isNull);
      expect(cleared.urgency, isNull);
    },
  );

  testWidgets(
    'plus action, menu actions, and detail taps trigger real callbacks',
    (tester) async {
      var createTapped = 0;
      var detailId = 0;
      var myFundraisersTapped = 0;
      var donationsTapped = 0;
      var verificationTapped = 0;

      await _pumpFeed(
        tester,
        loader: (_, _) async => FundraisingPage<FundraisingCampaign>(
          items: <FundraisingCampaign>[_campaign(9)],
          nextCursor: null,
        ),
        onOpenCreate: () => createTapped += 1,
        onOpenDetails: (id) => detailId = id,
        onOpenMyFundraisers: () => myFundraisersTapped += 1,
        onOpenMyDonations: () => donationsTapped += 1,
        onOpenVerification: () => verificationTapped += 1,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Create fundraiser'));
      await tester.pumpAndSettle();
      expect(createTapped, 1);

      await tester.tap(find.text('Campaign 9'));
      await tester.pumpAndSettle();
      expect(detailId, 9);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('My fundraisers'), findsWidgets);
      await tester.tap(find.text('My fundraisers').last);
      await tester.pumpAndSettle();
      expect(myFundraisersTapped, 1);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My donations'));
      await tester.pumpAndSettle();
      expect(donationsTapped, 1);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fundraising verification'));
      await tester.pumpAndSettle();
      expect(verificationTapped, 1);
    },
  );

  testWidgets(
    'My fundraisers menu activates owner view and renders owner statuses',
    (tester) async {
      final seenQueries = <FundraisingFeedQuery>[];
      final container = await _pumpFeed(
        tester,
        loader: (query, _) async {
          seenQueries.add(query);
          return FundraisingPage<FundraisingCampaign>(
            items: query.view == FundraisingFeedView.myFundraisers
                ? <FundraisingCampaign>[
                    _campaign(11, title: 'Draft', status: 'DRAFT'),
                    _campaign(12, title: 'Pending', status: 'PENDING_REVIEW'),
                  ]
                : <FundraisingCampaign>[_campaign(1)],
            nextCursor: null,
          );
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My fundraisers').last);
      await tester.pumpAndSettle();

      expect(
        container.read(fundraisingFeedQueryProvider).view,
        FundraisingFeedView.myFundraisers,
      );
      expect(seenQueries.last.view, FundraisingFeedView.myFundraisers);
      expect(find.text('Draft 11'), findsOneWidget);
      expect(find.text('Status: Draft'), findsOneWidget);
      expect(find.text('Continue draft'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(find.text('Pending 12'), findsOneWidget);
      expect(find.text('Status: Pending Review'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    },
  );

  testWidgets('owner edit action passes id and refreshes changed data', (
    tester,
  ) async {
    var editId = 0;
    var loadCalls = 0;

    await _pumpFeed(
      tester,
      loader: (query, _) async {
        loadCalls += 1;
        return FundraisingPage<FundraisingCampaign>(
          items: <FundraisingCampaign>[
            _campaign(
              21,
              title: loadCalls < 3 ? 'Before edit' : 'After edit',
              status: 'ACTIVE',
            ),
          ],
          nextCursor: null,
        );
      },
      onOpenEdit: (id) async {
        editId = id;
        return true;
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My fundraisers').last);
    await tester.pumpAndSettle();
    expect(find.text('Before edit 21'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(editId, 21);
    expect(find.text('After edit 21'), findsOneWidget);
  });

  testWidgets('narrow widths keep the layout stable', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpFeed(
      tester,
      loader: (_, _) async => const FundraisingPage<FundraisingCampaign>(
        items: [],
        nextCursor: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fundraising'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
