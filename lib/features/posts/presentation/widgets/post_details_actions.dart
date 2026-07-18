import 'package:flutter/material.dart';

import 'package:furtail_app/core/services/share_service.dart';
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

  Future<void> _toggleLike() async {
    if (_busy) return;
    setState(() => _busy = true);

    final p = widget.post;
    final currently = p.isLikedByMe;

    widget.onChanged(
      p.copyWith(
        likeCount: (p.likeCount + (currently ? -1 : 1)).clamp(0, 1 << 30),
        isLikedByMe: !currently,
      ),
    );

    try {
      final res =
          currently ? await _ds.unlikePost(p.id) : await _ds.likePost(p.id);
      final likeCount = (res['likeCount'] as num?)?.toInt();
      if (!mounted) return;
      if (likeCount != null) {
        widget.onChanged(
          p.copyWith(
            likeCount: likeCount,
            isLikedByMe: !currently,
          ),
        );
      }
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
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
          child: SocialActionRow(
            likeCount: p.likeCount,
            commentCount: p.commentCount,
            shareCount: p.shareCount,
            isLiked: p.isLikedByMe,
            onLike: _toggleLike,
            onComment: widget.onOpenComments,
            onShare: () {
              final fundraisingId = p.fundraisingCampaignId;
              if (fundraisingId != null) {
                ShareService.share(context,
                    type: 'fundraising', id: fundraisingId);
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
