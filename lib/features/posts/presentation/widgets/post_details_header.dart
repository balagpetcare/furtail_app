import 'package:flutter/material.dart';

import 'package:furtail_app/features/posts/data/models/post_model.dart';

/// AppBar title widget for the post details screen.
///
/// Shows: author avatar (tappable), author name, time ago.
class PostDetailsHeader extends StatelessWidget {
  final PostModel post;
  final VoidCallback onAuthorTap;

  const PostDetailsHeader({
    super.key,
    required this.post,
    required this.onAuthorTap,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAuthorTap,
      child: Row(
        children: [
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFEFEFEF),
            backgroundImage: (post.author.avatarUrl ?? '').isEmpty
                ? null
                : NetworkImage(post.author.avatarUrl!),
            child: (post.author.avatarUrl ?? '').isEmpty
                ? const Icon(Icons.person, color: Colors.black45, size: 18)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.author.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  _timeAgo(post.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium!
                      .copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
