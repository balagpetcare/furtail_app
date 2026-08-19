import 'package:flutter/material.dart';

import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/core/widgets/reaction_list_sheet.dart';
import 'package:furtail_app/core/widgets/reaction_summary.dart';
import 'package:furtail_app/core/widgets/social_action_row.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';

/// Action row for the post details screen.
class PostDetailsActions extends StatefulWidget {
  final PostModel post;
  final ValueChanged<PostModel> onChanged;
  final VoidCallback onOpenComments;

  const PostDetailsActions({
    super.key,
    required this.post,
    required this.onChanged,
    required this.onOpenComments,
  });

  @override
  State<PostDetailsActions> createState() => _PostDetailsActionsState();
}

class _PostDetailsActionsState extends State<PostDetailsActions> {
  final _ds = PostsRemoteDs();
  bool _busy = false;

  Future<void> _handleReact(String? reaction) async {
    if (_busy) return;
    setState(() => _busy = true);

    final p = widget.post;
    final currentlyLiked = p.isLikedByMe;
    final currentReaction = p.viewerReaction;
    final originalSummary = Map<String, int>.from(p.reactionSummary);

    var newSummary = Map<String, int>.from(originalSummary);
    var totalDelta = 0;
    var likeDelta = 0;

    // Remove old reaction
    if (currentReaction != null) {
      newSummary[currentReaction] = (newSummary[currentReaction] ?? 1) - 1;
      totalDelta -= 1;
      if (currentReaction == 'LIKE') likeDelta -= 1;
    } else if (currentlyLiked) {
      likeDelta -= 1;
    }

    // Add new reaction
    if (reaction != null) {
      newSummary[reaction] = (newSummary[reaction] ?? 0) + 1;
      totalDelta += 1;
      if (reaction == 'LIKE') likeDelta += 1;
    }

    final isNowLiked = reaction != null;

    widget.onChanged(
      p.copyWith(
        viewerReaction: reaction,
        reactionSummary: newSummary,
        totalReactionCount: p.totalReactionCount + totalDelta,
        isLikedByMe: isNowLiked,
        likeCount: (p.likeCount + likeDelta).clamp(0, 1 << 30),
      ),
    );

    try {
      final res = reaction == null
          ? await _ds.unlikePost(p.id)
          : await _ds.likePost(p.id, reaction: reaction);

      if (!mounted) return;

      final likeCount =
          (res['likeCount'] as num?)?.toInt() ?? p.likeCount + likeDelta;
      final commentCount =
          (res['commentCount'] as num?)?.toInt() ?? p.commentCount;
      final isLikedByMe = (res['isLikedByMe'] as bool?) ?? isNowLiked;
      final viewerReaction = res.containsKey('viewerReaction')
          ? res['viewerReaction']?.toString()
          : reaction;
      final reactionSummary = res.containsKey('reactionSummary')
          ? PostModel.reactionSummaryFrom(res['reactionSummary'])
          : newSummary;
      final totalReactionCount =
          (res['totalReactionCount'] as num?)?.toInt() ??
          p.totalReactionCount + totalDelta;

      widget.onChanged(
        p.copyWith(
          likeCount: likeCount,
          commentCount: commentCount,
          isLikedByMe: isLikedByMe,
          viewerReaction: viewerReaction,
          reactionSummary: reactionSummary,
          totalReactionCount: totalReactionCount,
        ),
      );
    } catch (_) {
      // keep optimistic state
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.totalReactionCount > 0 || p.likeCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: GestureDetector(
              onTap: () => showReactionListSheet(context, p),
              behavior: HitTestBehavior.opaque,
              child: ReactionSummary(
                summary: p.reactionSummary,
                totalCount: p.totalReactionCount > 0
                    ? p.totalReactionCount
                    : p.likeCount,
                topReactors: p.topReactors,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
          child: SocialActionRow(
            likeCount: p.likeCount,
            commentCount: p.commentCount,
            shareCount: p.shareCount,
            isLiked: p.isLikedByMe,
            viewerReaction: p.viewerReaction,
            onReact: _handleReact,
            onLike: () => _handleReact(p.isLikedByMe ? null : 'LIKE'),
            onComment: widget.onOpenComments,
            onShare: () {
              final fundraisingId = p.fundraisingCampaignId;
              if (fundraisingId != null) {
                ShareService.share(
                  context,
                  type: 'fundraising',
                  id: fundraisingId,
                );
              } else {
                ShareService.share(context, type: 'post', id: p.id);
              }
            },
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
