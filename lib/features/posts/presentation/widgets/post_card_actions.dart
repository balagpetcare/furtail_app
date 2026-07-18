import 'package:flutter/material.dart';

import 'package:furtail_app/core/widgets/social_action_row.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';

/// Action row for a feed post card.
class PostCardActions extends StatelessWidget {
  final PostModel post;
  final VoidCallback onLike;
  final VoidCallback onOpenComments;
  final VoidCallback onShare;

  const PostCardActions({
    super.key,
    required this.post,
    required this.onLike,
    required this.onOpenComments,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      child: SocialActionRow(
        likeCount: post.likeCount,
        commentCount: post.commentCount,
        shareCount: post.shareCount,
        isLiked: post.isLikedByMe,
        onLike: onLike,
        onComment: onOpenComments,
        onShare: onShare,
      ),
    );
  }
}
