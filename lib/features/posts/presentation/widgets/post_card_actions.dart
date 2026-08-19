import 'package:flutter/material.dart';

import 'package:furtail_app/core/widgets/reaction_list_sheet.dart';
import 'package:furtail_app/core/widgets/reaction_summary.dart';
import 'package:furtail_app/core/widgets/social_action_row.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';

/// Action row for a feed post card.
class PostCardActions extends StatelessWidget {
  final PostModel post;
  final ValueChanged<String?>? onReact;
  final VoidCallback onLike;
  final VoidCallback onOpenComments;
  final VoidCallback onShare;

  const PostCardActions({
    super.key,
    required this.post,
    this.onReact,
    required this.onLike,
    required this.onOpenComments,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.totalReactionCount > 0 || post.likeCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: GestureDetector(
                onTap: () => showReactionListSheet(context, post),
                behavior: HitTestBehavior.opaque,
                child: ReactionSummary(
                  summary: post.reactionSummary,
                  totalCount: post.totalReactionCount > 0
                      ? post.totalReactionCount
                      : post.likeCount,
                  topReactors: post.topReactors,
                ),
              ),
            ),
          SocialActionRow(
            likeCount: post.likeCount,
            commentCount: post.commentCount,
            shareCount: post.shareCount,
            isLiked: post.isLikedByMe,
            viewerReaction: post.viewerReaction,
            onReact: onReact ?? (val) => onLike(),
            onLike: onLike,
            onComment: onOpenComments,
            onShare: onShare,
          ),
        ],
      ),
    );
  }
}
