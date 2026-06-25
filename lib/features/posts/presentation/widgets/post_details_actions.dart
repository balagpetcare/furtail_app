import 'package:flutter/material.dart';

import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';

/// Action row for the post details screen.
///
/// Shows counts (likes, comments) and three buttons: Paw/Like, Comment,
/// Share. Tapping Paw optimistically updates the count via [onChanged].
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

    // optimistic update
    widget.onChanged(
      PostModel(
        id: p.id,
        type: p.type,
        caption: p.caption,
        context: p.context,
        createdAt: p.createdAt,
        author: p.author,
        media: p.media,
        likeCount: (p.likeCount + (currently ? -1 : 1)).clamp(0, 1 << 30),
        commentCount: p.commentCount,
        isLikedByMe: !currently,
        category: p.category,
        fundraisingCampaignId: p.fundraisingCampaignId,
        fundraisingEmbed: p.fundraisingEmbed,
      ),
    );

    try {
      final res =
          currently ? await _ds.unlikePost(p.id) : await _ds.likePost(p.id);
      final likeCount = (res['likeCount'] as num?)?.toInt();
      if (!mounted) return;
      if (likeCount != null) {
        final u = widget.post;
        widget.onChanged(
          PostModel(
            id: u.id,
            type: u.type,
            caption: u.caption,
            context: u.context,
            createdAt: u.createdAt,
            author: u.author,
            media: u.media,
            likeCount: likeCount,
            commentCount: u.commentCount,
            isLikedByMe: !currently,
            category: u.category,
            fundraisingCampaignId: u.fundraisingCampaignId,
            fundraisingEmbed: u.fundraisingEmbed,
          ),
        );
      }
    } catch (_) {
      // ignore
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
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${p.likeCount} Paws · ${p.commentCount} comments · ${p.shareCount} shares',
              style: Theme.of(context).textTheme.bodySmall!
                  .copyWith(color: Colors.black54),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
          child: Row(
            children: [
              Expanded(
                child: _ReactionButton(
                  icon: p.isLikedByMe ? Icons.pets : Icons.pets_outlined,
                  label: 'Paw',
                  selected: p.isLikedByMe,
                  onTap: _toggleLike,
                ),
              ),
              Expanded(
                child: _ReactionButton(
                  icon: Icons.comment_outlined,
                  label: 'Comment',
                  onTap: widget.onOpenComments,
                ),
              ),
              Expanded(
                child: _ReactionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () {
                    final fundraisingId = p.fundraisingCampaignId;
                    if (fundraisingId != null) {
                      ShareService.share(context,
                          type: 'fundraising', id: fundraisingId);
                    } else {
                      ShareService.share(context,
                          type: 'post', id: p.id);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20,
                color: selected ? Theme.of(context).colorScheme.primary : null),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                fontWeight: FontWeight.w700,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
