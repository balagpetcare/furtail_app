import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/core/storage/local_storage.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/presentation/widgets/comments_bottom_sheet.dart';
import 'package:furtail_app/features/posts/presentation/widgets/comments_preview_section.dart';
import 'package:furtail_app/features/posts/presentation/widgets/report_bottom_sheet.dart';

import '../../data/fundraising_error_mapper.dart';
import '../../data/models/fundraising_models.dart';
import '../../widgets/donate_now_bar.dart';
import '../providers/fundraising_providers.dart';
import '../widgets/details/fundraising_details_dialogs.dart';
import '../widgets/details/fundraising_countdown_card.dart';
import '../widgets/details/fundraising_details_header.dart';
import '../widgets/details/fundraising_donations_preview.dart';
import '../widgets/details/fundraising_media_carousel.dart';
import '../widgets/details/fundraising_progress_section.dart';
import '../widgets/details/fundraising_reactions_section.dart';
import '../widgets/details/fundraising_updates_section.dart';
import '../widgets/details/read_more_text.dart';
import '../widgets/fundraising_donation_checkout_sheet.dart';
import '../widgets/fundraising_status_views.dart';
import 'fundraising_donation_result_screen.dart';
import 'fundraising_donations_screen.dart';
import 'fundraising_edit_screen.dart';
import 'fundraising_payout_methods_screen.dart';
import 'fundraising_update_editor_screen.dart';
import 'fundraising_withdraw_request_screen.dart';

class FundraisingDetailsScreen extends ConsumerStatefulWidget {
  const FundraisingDetailsScreen({
    super.key,
    required this.campaignId,
    this.currentUserIdLoader,
    this.postLoader,
  });

  final int campaignId;
  final Future<int?> Function()? currentUserIdLoader;
  final Future<PostModel> Function(int postId)? postLoader;

  @override
  ConsumerState<FundraisingDetailsScreen> createState() =>
      _FundraisingDetailsScreenState();
}

class _FundraisingDetailsScreenState
    extends ConsumerState<FundraisingDetailsScreen> {
  bool _donationBusy = false;

  Future<void> _refreshCampaign() async {
    ref.invalidate(fundraisingCampaignProvider(widget.campaignId));
    ref.invalidate(fundraisingFeedProvider);
    await ref.read(fundraisingCampaignProvider(widget.campaignId).future);
  }

  @override
  Widget build(BuildContext context) {
    final asyncValue = ref.watch(
      fundraisingCampaignProvider(widget.campaignId),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: asyncValue.when(
          loading: () => const FundraisingLoadingView(
            message: 'Loading fundraiser details...',
          ),
          error: (error, _) {
            final safeError = mapFundraisingSafeError(error);
            return FundraisingErrorView(
              title: fundraisingErrorTitle(safeError),
              message: fundraisingErrorDescription(safeError),
              onBack: () => Navigator.maybePop(context),
              onRetry: _refreshCampaign,
            );
          },
          data: (campaign) => FutureBuilder<int?>(
            future:
                widget.currentUserIdLoader?.call() ?? LocalStorage.getUserId(),
            builder: (context, userSnap) {
              final currentUserId = userSnap.data ?? -1;
              final isOwner =
                  currentUserId > 0 && currentUserId == campaign.author.id;
              return FutureBuilder<PostModel>(
                future:
                    widget.postLoader?.call(campaign.postId) ??
                    PostsRemoteDs().getPostById(postId: campaign.postId),
                builder: (context, postSnap) {
                  final post = postSnap.data;
                  return _DetailsBody(
                    campaign: campaign,
                    isOwner: isOwner,
                    post: post,
                    donationBusy: _donationBusy,
                    onRefresh: _refreshCampaign,
                    onDonationBusyChanged: (value) {
                      if (mounted) {
                        setState(() => _donationBusy = value);
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DetailsBody extends ConsumerWidget {
  const _DetailsBody({
    required this.campaign,
    required this.isOwner,
    required this.post,
    required this.donationBusy,
    required this.onRefresh,
    required this.onDonationBusyChanged,
  });

  final FundraisingCampaign campaign;
  final bool isOwner;
  final PostModel? post;
  final bool donationBusy;
  final Future<void> Function() onRefresh;
  final ValueChanged<bool> onDonationBusyChanged;

  List<String> _extractTags(String? text) {
    if (text == null || text.trim().isEmpty) return const <String>[];
    final matches = RegExp(r'#[\w\u0980-\u09FF]+').allMatches(text);
    return matches
        .map((match) => match.group(0)!)
        .toSet()
        .take(8)
        .toList(growable: false);
  }

  Future<void> _openUpdateEditor(BuildContext context, WidgetRef ref) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FundraisingUpdateEditorScreen(campaignId: campaign.id),
      ),
    );
    if (ok == true) {
      ref.invalidate(fundraisingUpdatesProvider(campaign.id));
      ref.invalidate(fundraisingCampaignProvider(campaign.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tags = _extractTags(campaign.caption);
    final likeCount = post?.likeCount ?? 0;
    final commentCount = post?.commentCount ?? 0;
    final isLikedByMe = post?.isLikedByMe ?? false;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      bottomNavigationBar: DonateNowBar(
        onDonate: campaign.isDonationEligible && !donationBusy
            ? () async {
                final draft = await showFundraisingDonationCheckoutSheet(
                  context,
                );
                if (draft == null || !context.mounted) return;
                onDonationBusyChanged(true);
                try {
                  final checkoutController = ref.read(
                    fundraisingDonationCheckoutControllerProvider,
                  );
                  await checkoutController.initialize();
                  final record = await checkoutController.startCheckout(
                    campaignId: campaign.id,
                    campaignTitle: campaign.title,
                    draft: draft,
                  );
                  if (!context.mounted || record == null) {
                    final failure = checkoutController.lastFailure;
                    if (failure?.message != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(failure!.message!)),
                      );
                    }
                    return;
                  }
                  if (record.isTerminal) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FundraisingDonationResultScreen(
                          attemptId: record.attemptId,
                        ),
                      ),
                    );
                    return;
                  }
                  final opened = await checkoutController.openProvider(
                    record.attemptId,
                  );
                  if (!context.mounted) return;
                  if (!opened) {
                    final failure = checkoutController.lastFailure;
                    if (failure?.message != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(failure!.message!)),
                      );
                    }
                    return;
                  }
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FundraisingDonationProcessingScreen(
                        attemptId: record.attemptId,
                      ),
                    ),
                  );
                  ref.invalidate(fundraisingCampaignProvider(campaign.id));
                  ref.invalidate(fundraisingFeedProvider);
                  ref.invalidate(fundraisingDonationsProvider(campaign.id));
                } finally {
                  onDonationBusyChanged(false);
                }
              }
            : null,
        isLoading: donationBusy,
        label: campaign.isDonationEligible
            ? 'Donate Now'
            : 'Donations unavailable',
        disabledMessage: campaign.isDonationEligible
            ? null
            : campaign.donationUnavailableMessage,
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  FundraisingDetailsHeader(
                    author: campaign.author,
                    createdAt: campaign.createdAt,
                    isOwner: isOwner,
                    onBack: () => Navigator.maybePop(context),
                    onShare: () => ShareService.share(
                      context,
                      type: 'fundraising',
                      id: campaign.id,
                    ),
                    onReport: () {
                      ReportBottomSheet.show(
                        context,
                        targetType: ReportTargetType.fundraising,
                        targetId: campaign.id,
                      );
                    },
                    onEdit: () async {
                      final ok = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) =>
                              FundraisingEditScreen(campaign: campaign),
                        ),
                      );
                      if (ok == true) {
                        ref.invalidate(
                          fundraisingCampaignProvider(campaign.id),
                        );
                        ref.invalidate(fundraisingFeedProvider);
                      }
                    },
                    onPostUpdate: () => _openUpdateEditor(context, ref),
                    onDelete: () async {
                      final confirmed = await confirmDialog(
                        context,
                        title: 'Delete fundraiser?',
                        message:
                            'This fundraiser will be removed from the public feed.',
                        okText: 'Delete',
                      );
                      if (confirmed != true) return;
                      final repo = ref.read(fundraisingRepositoryProvider);
                      await repo.deleteCampaign(campaignId: campaign.id);
                      ref.invalidate(fundraisingFeedProvider);
                      if (context.mounted) Navigator.maybePop(context);
                    },
                    onPayoutMethods: isOwner
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const FundraisingPayoutMethodsScreen(),
                              ),
                            );
                          }
                        : null,
                    onWithdraw: isOwner
                        ? () async {
                            final ok = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    FundraisingWithdrawRequestScreen(
                                      campaign: campaign,
                                    ),
                              ),
                            );
                            if (ok == true) {
                              ref.invalidate(
                                fundraisingCampaignProvider(campaign.id),
                              );
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 10),
                  if (campaign.media.isNotEmpty)
                    FundraisingMediaCarousel(media: campaign.media),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: theme.colorScheme.shadow.withValues(
                              alpha: 0.07,
                            ),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MetaPill(
                                  icon: Icons.sell_outlined,
                                  label: campaign.category ?? 'Fundraiser',
                                ),
                                if ((campaign.locationText ?? '')
                                    .trim()
                                    .isNotEmpty)
                                  _MetaPill(
                                    icon: Icons.location_on_outlined,
                                    label: campaign.locationText!.trim(),
                                  ),
                                _MetaPill(
                                  icon: Icons.schedule_outlined,
                                  label: _statusLabel(campaign.status),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              campaign.title,
                              softWrap: true,
                              style: context.appText.displayMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            if ((campaign.caption ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ReadMoreText(
                                text: campaign.caption!.trim(),
                                maxLines: 4,
                              ),
                            ],
                            if (tags.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: tags
                                    .map((tag) => Chip(label: Text(tag)))
                                    .toList(growable: false),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (campaign.status.trim().toUpperCase() == 'PENDING_REVIEW')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: _ReviewStatusNotice(
                        donationsEnabled: campaign.isDonationEligible,
                      ),
                    ),
                  if ((campaign.endsAt ?? campaign.deadline) != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: FundraisingCountdownCard(campaign: campaign),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: FundraisingProgressSection(campaign: campaign),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: theme.colorScheme.shadow.withValues(
                              alpha: 0.05,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: FundraisingReactionsSection(
                          postId: campaign.postId,
                          fundraisingId: campaign.id,
                          initialLikedByMe: isLikedByMe,
                          initialLikeCount: likeCount,
                          commentCount: commentCount,
                        ),
                      ),
                    ),
                  ),
                  _SectionCard(
                    title: 'Recent donations',
                    actionLabel: 'View all',
                    onAction: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FundraisingDonationsScreen(
                            campaignId: campaign.id,
                          ),
                        ),
                      );
                    },
                    child: FundraisingDonationsPreview(
                      campaign: campaign,
                      onViewAll: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FundraisingDonationsScreen(
                              campaignId: campaign.id,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _SectionCard(
                    title: 'Updates',
                    actionLabel: isOwner ? 'Add update' : null,
                    onAction: isOwner
                        ? () => _openUpdateEditor(context, ref)
                        : null,
                    child: FundraisingUpdatesList(
                      campaignId: campaign.id,
                      isOwner: isOwner,
                    ),
                  ),
                  _SectionCard(
                    title: 'Comments',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CommentsPreviewSection(
                          postId: campaign.postId,
                          previewCount: 20,
                          totalCount: commentCount,
                          showTitle: false,
                          onViewAll: () => showCommentsBottomSheet(
                            context,
                            postId: campaign.postId,
                            autoFocusComposer: false,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () => showCommentsBottomSheet(
                            context,
                            postId: campaign.postId,
                            autoFocusComposer: true,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.mode_comment_outlined,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Write a comment...',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String raw) {
  final words = raw
      .trim()
      .toLowerCase()
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}');
  return words.isEmpty ? 'Fundraiser' : words.join(' ');
}

class _ReviewStatusNotice extends StatelessWidget {
  const _ReviewStatusNotice({required this.donationsEnabled});

  final bool donationsEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.fact_check_outlined,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review in progress',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  donationsEnabled
                      ? 'This fundraiser is awaiting moderation and is currently accepting donations.'
                      : 'This fundraiser is awaiting moderation. Donation availability is controlled by the server policy.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.055),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (actionLabel != null && onAction != null)
                    TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
