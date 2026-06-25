import 'package:flutter/material.dart';

import 'package:furtail_app/features/posts/data/models/post_model.dart';

/// Action row for a feed post card.
///
/// Shows counts (likes, comments, shares) and three buttons: Paw/Like,
/// Comment, Share.
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Text(
            '${post.likeCount} Paws · ${post.commentCount} comments · ${post.shareCount} shares',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black54),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
          child: Row(
            children: [
              Expanded(
                child: _ReactionButton(
                  icon: post.isLikedByMe
                      ? Icons.pets
                      : Icons.pets_outlined,
                  label: 'Paw',
                  selected: post.isLikedByMe,
                  onTap: onLike,
                ),
              ),
              Expanded(
                child: _ReactionButton(
                  icon: Icons.comment_outlined,
                  label: 'Comment',
                  onTap: onOpenComments,
                ),
              ),
              Expanded(
                child: _ReactionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: onShare,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ReactionButton({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.black54;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
