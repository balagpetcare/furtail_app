import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/presentation/providers/fundraising_providers.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_details_screen.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

FundraisingCampaign _campaign({
  required int id,
  required int authorId,
  String status = 'PENDING_REVIEW',
  String title =
      'বাংলা ও English মিশ্রিত একটি খুব লম্বা fundraiser title যা wrap হওয়া উচিত এবং overflow করা যাবে না',
}) {
  return FundraisingCampaign(
    id: id,
    postId: 900 + id,
    title: title,
    targetAmount: 1000,
    targetAmountMinor: 1000,
    monthlyGoalMinor: null,
    fundingMode: 'ONE_TIME',
    startsAt: DateTime(2026, 7, 1),
    endsAt: DateTime(2026, 8, 1),
    deadline: DateTime(2026, 8, 1),
    nextReviewAt: null,
    publishedAt: DateTime(2026, 7, 10),
    createdAt: DateTime(2026, 7, 10),
    status: status,
    author: FundraisingAuthor(
      id: authorId,
      displayName: 'Owner Name',
      username: 'owner',
      avatarUrl: null,
    ),
    caption:
        'এই ক্যাম্পেইনের লক্ষ্য হলো support and updates নিয়ে supporters-দের informed রাখা। #help #fundraising',
    media: const <FundraisingMediaItem>[],
    stats: const FundraisingStats(
      raisedAmount: 1250,
      withdrawnAmount: 250,
      donorsCount: 3,
    ),
    isAccountVerified: true,
    category: 'Treatment',
    locationText: 'Dhaka',
    last3Donors: const <FundraisingDonor>[],
  );
}

PostModel _post({
  required int id,
  required int likeCount,
  required int commentCount,
}) {
  return PostModel(
    id: id,
    type: 'TEXT',
    category: 'FUNDRAISING',
    fundraisingCampaignId: id - 900,
    caption: 'Story with mixed বাংলা and English text for wrapping.',
    createdAt: DateTime(2026, 7, 10),
    author: PostAuthorModel(id: 1, name: 'Owner Name'),
    media: const <PostMediaModel>[],
    likeCount: likeCount,
    commentCount: commentCount,
    isLikedByMe: false,
    isBookmarkedByMe: false,
    privacy: 'PUBLIC',
    shareCount: 0,
    viewCount: 0,
    isReportedByMe: false,
    isFollowingAuthor: false,
    postType: 'GENERAL',
    taggedPetIds: const <int>[],
    taggedPets: const <PostTaggedPetModel>[],
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required FundraisingCampaign campaign,
  required Future<int?> Function() currentUserIdLoader,
  required Future<PostModel> Function(int postId) postLoader,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fundraisingCampaignProvider(
          campaign.id,
        ).overrideWith((ref) async => campaign),
        fundraisingUpdatesProvider(
          campaign.id,
        ).overrideWith((ref) async => const <FundraisingUpdateItem>[]),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FundraisingDetailsScreen(
          campaignId: campaign.id,
          currentUserIdLoader: currentUserIdLoader,
          postLoader: postLoader,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows owner update action and pending-review donation CTA', (
    tester,
  ) async {
    final campaign = _campaign(id: 1, authorId: 7);

    await _pumpScreen(
      tester,
      campaign: campaign,
      currentUserIdLoader: () async => 7,
      postLoader: (postId) async =>
          _post(id: postId, likeCount: 18, commentCount: 4),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Add update'), findsOneWidget);
    expect(find.text('Donate Now'), findsOneWidget);

    final donateButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton).last,
    );
    expect(donateButton.onPressed, isNotNull);

    final buttonSize = tester.getSize(find.byType(ElevatedButton).last);
    expect(buttonSize.width, greaterThan(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides owner-only update controls for ordinary users', (
    tester,
  ) async {
    final campaign = _campaign(id: 2, authorId: 7);

    await _pumpScreen(
      tester,
      campaign: campaign,
      currentUserIdLoader: () async => 99,
      postLoader: (postId) async =>
          _post(id: postId, likeCount: 2, commentCount: 1),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Add update'), findsNothing);
    expect(find.text('Donate Now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders long mixed-language content on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final campaign = _campaign(id: 3, authorId: 7);

    await _pumpScreen(
      tester,
      campaign: campaign,
      currentUserIdLoader: () async => 7,
      postLoader: (postId) async =>
          _post(id: postId, likeCount: 120, commentCount: 42),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('বাংলা ও English'), findsOneWidget);
    expect(find.text('Donate Now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
