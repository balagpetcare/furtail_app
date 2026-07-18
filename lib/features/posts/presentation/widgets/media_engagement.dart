import 'package:flutter/material.dart';

import 'package:furtail_app/core/widgets/social_action_row.dart';

class MediaEngagementSummary {
  final int mediaId;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isLiked;

  const MediaEngagementSummary({
    required this.mediaId,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.isLiked,
  });

  MediaEngagementSummary copyWith({
    int? likeCount,
    int? commentCount,
    int? shareCount,
    bool? isLiked,
  }) {
    return MediaEngagementSummary(
      mediaId: mediaId,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

class MediaEngagementActions extends StatelessWidget {
  final MediaEngagementSummary summary;
  final VoidCallback onLikeToggle;
  final VoidCallback onCommentPressed;
  final VoidCallback onSharePressed;

  const MediaEngagementActions({
    super.key,
    required this.summary,
    required this.onLikeToggle,
    required this.onCommentPressed,
    required this.onSharePressed,
  });

  @override
  Widget build(BuildContext context) {
    return SocialActionRow(
      likeCount: summary.likeCount,
      commentCount: summary.commentCount,
      shareCount: summary.shareCount,
      isLiked: summary.isLiked,
      onLike: onLikeToggle,
      onComment: onCommentPressed,
      onShare: onSharePressed,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white70,
      selectedColor: Theme.of(context).colorScheme.primary,
      dividerColor: Colors.white10,
      showDivider: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}
