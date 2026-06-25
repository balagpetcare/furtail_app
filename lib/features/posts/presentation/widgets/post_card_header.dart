import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/app_typography.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';

/// The header section of a feed post card.
///
/// Shows author avatar, name, optional verified badge, time ago, and a
/// three-dot icon that calls [onMoreMenu] to open the action sheet.
class PostCardHeader extends StatelessWidget {
  final PostModel post;
  final bool isVerified;
  final VoidCallback onProfileTap;
  final VoidCallback? onMoreMenu;

  const PostCardHeader({
    super.key,
    required this.post,
    required this.isVerified,
    required this.onProfileTap,
    this.onMoreMenu,
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: FurtailNetworkAvatar(
        imageUrl: post.author.avatarUrl,
        displayName: post.author.name,
        radius: 20,
        backgroundColor: const Color(0xFFEFEFEF),
        foregroundColor: Colors.black45,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              post.author.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cardTitle(context)
                  .copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (isVerified) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.verified,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
      subtitle: Text(
        _timeAgo(post.createdAt),
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.black54),
      ),
      trailing: onMoreMenu == null
          ? null
          : IconButton(
              icon: const Icon(Icons.more_horiz, color: Colors.black54),
              splashRadius: 20,
              onPressed: onMoreMenu,
            ),
      onTap: onProfileTap,
    );
  }
}
