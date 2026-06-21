import 'package:furtail_app/core/analytics/analytics_provider.dart';
import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/core/storage/local_storage.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/presentation/widgets/report_bottom_sheet.dart';
import 'package:furtail_app/features/posts/presentation/widgets/comments_preview_section.dart';
import 'package:furtail_app/features/posts/presentation/widgets/comments_bottom_sheet.dart';

import '../../data/models/fundraising_models.dart';
import '../providers/fundraising_providers.dart';
import '../../widgets/donate_now_bar.dart';
import 'fundraising_donations_screen.dart';
import 'fundraising_edit_screen.dart';
import 'fundraising_update_editor_screen.dart';
import 'fundraising_payout_methods_screen.dart';
import 'fundraising_withdraw_request_screen.dart';

import '../widgets/details/fundraising_details_header.dart';
import '../widgets/details/fundraising_media_carousel.dart';
import '../widgets/details/read_more_text.dart';
import '../widgets/details/fundraising_progress_section.dart';
import '../widgets/details/fundraising_reactions_section.dart';
import '../widgets/details/fundraising_donations_preview.dart';
import '../widgets/details/fundraising_updates_section.dart';
import '../widgets/details/fundraising_details_dialogs.dart';

/// Donation/Fundraising single page.
/// Refactored in Phase-2: details UI split into reusable components.
class FundraisingDetailsScreen extends ConsumerWidget {
  final int campaignId;
  const FundraisingDetailsScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(fundraisingCampaignProvider(campaignId));
    final postsDs = PostsRemoteDs();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: asyncValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (FundraisingCampaign c) {
            return FutureBuilder<int?>(
              future: LocalStorage.getUserId(),
              builder: (context, snap) {
                final myId = snap.data ?? -1;
                final isOwner = myId > 0 && myId == c.author.id;

                return FutureBuilder<PostModel>(
                  future: postsDs.getPostById(postId: c.postId),
                  builder: (context, postSnap) {
                    final post = postSnap.data;
                    final likeCount = post?.likeCount ?? 0;
                    final commentCount = post?.commentCount ?? 0;
                    final isLikedByMe = post?.isLikedByMe ?? false;

                    return Stack(
                      children: [
                        ListView(
                          padding: const EdgeInsets.only(bottom: 92),
                          children: [
                            const SizedBox(height: 10),
                            FundraisingDetailsHeader(
                              author: c.author,
                              createdAt: c.createdAt,
                              isOwner: isOwner,
                              onBack: () => Navigator.maybePop(context),
                              onShare: () => ShareService.share(
                                context,
                                type: 'fundraising',
                                id: campaignId,
                              ),
                              onReport: () {
                                ReportBottomSheet.show(
                                  context,
                                  targetType: ReportTargetType.fundraising,
                                  targetId: campaignId,
                                );
                              },
                              onEdit: () async {
                                final ok = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => FundraisingEditScreen(campaign: c),
                                  ),
                                );
                                if (ok == true) {
                                  ref.invalidate(fundraisingCampaignProvider(campaignId));
                                  ref.invalidate(fundraisingFeedProvider);
                                }
                              },
                              onPayoutMethods: isOwner
                                  ? () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const FundraisingPayoutMethodsScreen(),
                                        ),
                                      );
                                    }
                                  : null,
                              onWithdraw: isOwner
                                  ? () async {
                                      final ok = await Navigator.of(context).push<bool>(
                                        MaterialPageRoute(
                                          builder: (_) => FundraisingWithdrawRequestScreen(campaign: c),
                                        ),
                                      );
                                      if (ok == true) {
                                        ref.invalidate(fundraisingCampaignProvider(campaignId));
                                        ref.invalidate(fundraisingWithdrawRequestsProvider(c.id));
                                      }
                                    }
                                  : null,
                              onPostUpdate: () async {
                                final ok = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => FundraisingUpdateEditorScreen(campaignId: c.id),
                                  ),
                                );
                                if (ok == true) {
                                  ref.invalidate(fundraisingUpdatesProvider(c.id));
                                }
                              },
                              onDelete: () async {
                                final confirmed = await confirmDialog(
                                  context,
                                  title: 'Delete post?',
                                  message: 'This fundraising post will be removed.',
                                  okText: 'Delete',
                                );
                                if (confirmed != true) return;
                                final repo = ref.read(fundraisingRepositoryProvider);
                                await repo.deleteCampaign(campaignId: c.id);
                                ref.invalidate(fundraisingFeedProvider);
                                if (context.mounted) Navigator.maybePop(context);
                              },
                            ),
                            const SizedBox(height: 10),
                            if (c.media.isNotEmpty)
                              FundraisingMediaCarousel(media: c.media)
                            else
                              const SizedBox.shrink(),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.title,
                                    style: context.appText.displayMedium!.copyWith(fontWeight: FontWeight.w800, height: 1.05),
                                  ),
                                  const SizedBox(height: 8),
                                  if ((c.caption ?? '').trim().isNotEmpty)
                                    ReadMoreText(text: c.caption!.trim(), maxLines: 3),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: FundraisingProgressSection(campaign: c),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: FundraisingReactionsSection(
                                postId: c.postId,
                                fundraisingId: campaignId,
                                initialLikedByMe: isLikedByMe,
                                initialLikeCount: likeCount,
                                commentCount: commentCount,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: FundraisingDonationsPreview(
                                campaign: c,
                                onViewAll: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FundraisingDonationsScreen(campaignId: c.id),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: FundraisingUpdatesHeader(
                                isOwner: isOwner,
                                onAdd: () async {
                                  final ok = await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => FundraisingUpdateEditorScreen(campaignId: c.id),
                                    ),
                                  );
                                  if (ok == true) {
                                    ref.invalidate(fundraisingUpdatesProvider(c.id));
                                  }
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: FundraisingUpdatesList(campaignId: c.id, isOwner: isOwner),
                            ),
                            const SizedBox(height: 14),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Comments',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ✅ Reuse the same comment preview UI used in Single Post page.
                                  CommentsPreviewSection(
                                    postId: c.postId,
                                    previewCount: 20,
                                    totalCount: commentCount,
                                    showTitle: false,
                                    onViewAll: () => showCommentsBottomSheet(
                                      context,
                                      postId: c.postId,
                                      autoFocusComposer: false,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // ✅ "Write comment" opens bottom sheet (keyboard-safe)
                                  InkWell(
                                    onTap: () => showCommentsBottomSheet(
                                      context,
                                      postId: c.postId,
                                      autoFocusComposer: true,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Row(
                                        children: const [
                                          Icon(Icons.mode_comment_outlined, size: 18, color: Colors.black54),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Write a comment…',
                                              style: TextStyle(color: Colors.black54),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Material(
                            color: Colors.transparent,
                            elevation: 0,
                            child: DonateNowBar(
                              onDonate: () async {
                                final amount = await askDonationAmount(context);
                                if (amount == null) return;
                                final repo = ref.read(fundraisingRepositoryProvider);
                                await repo.donate(campaignId: c.id, amount: amount);
                                await ref.read(analyticsServiceProvider).logDonationMade(
                                      campaignId: c.id,
                                      amount: amount,
                                    );
                                ref.invalidate(fundraisingCampaignProvider(campaignId));
                                ref.invalidate(fundraisingFeedProvider);
                                ref.invalidate(fundraisingDonationsProvider(campaignId));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Donation successful')),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
