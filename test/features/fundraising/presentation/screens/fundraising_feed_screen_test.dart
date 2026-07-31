import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_feed_screen.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

Future<void> _pumpFeed(
  WidgetTester tester, {
  required FundraisingFeedPageLoader loader,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FundraisingFeedScreen(pageLoader: loader),
      ),
    ),
  );
}

FundraisingCampaign _campaign(
  int id, {
  String title = 'Campaign',
  String status = 'ACTIVE',
  DateTime? publishedAt,
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
    endsAt: DateTime(2026, 8, 1),
    deadline: DateTime(2026, 8, 1),
    nextReviewAt: null,
    publishedAt: publishedAt ?? DateTime(2026, 7, 10),
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
    category: 'Treatment',
    locationText: 'Dhaka',
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

  testWidgets('renders a populated feed', (tester) async {
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

    expect(find.text('No fundraisers yet'), findsOneWidget);
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

  testWidgets('does not show false empty state while refreshing', (
    tester,
  ) async {
    final refreshCompleter = Completer<FundraisingPage<FundraisingCampaign>>();
    var firstCall = true;

    await _pumpFeed(
      tester,
      loader: (_, _) {
        if (firstCall) {
          firstCall = false;
          return Future<FundraisingPage<FundraisingCampaign>>.value(
            FundraisingPage<FundraisingCampaign>(
              items: <FundraisingCampaign>[_campaign(1)],
              nextCursor: null,
            ),
          );
        }
        return refreshCompleter.future;
      },
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();

    expect(find.text('Campaign 1'), findsOneWidget);
    expect(find.text('No fundraisers yet'), findsNothing);

    refreshCompleter.complete(
      FundraisingPage<FundraisingCampaign>(
        items: <FundraisingCampaign>[_campaign(1)],
        nextCursor: null,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('narrow widths keep the short title layout stable', (
    tester,
  ) async {
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

    expect(find.text('Fundraising'), findsOneWidget);
  });
}
