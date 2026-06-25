import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/posts/data/models/post_comment_model.dart';

/// Renders a single comment row with avatar, author name, time, text,
/// and action buttons (like, reply, report).
class CommentTile extends StatelessWidget {
  final PostCommentModel item;
  final bool isReply;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback? onReport;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isHighlighted;

  const CommentTile({
    super.key,
    required this.item,
    required this.isReply,
    required this.onLike,
    required this.onReply,
    required this.onReport,
    this.onEdit,
    this.onDelete,
    this.isHighlighted = false,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 4) return '${weeks}w';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '${months}mo';
    final years = (diff.inDays / 365).floor();
    return '${years}y';
  }

  @override
  Widget build(BuildContext context) {
    final hasMenu = onEdit != null || onDelete != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: isReply ? 16 : 18,
          backgroundColor: const Color(0xFFEFEFEF),
          backgroundImage: (item.author.avatarUrl ?? '').isEmpty
              ? null
              : NetworkImage(item.author.avatarUrl!),
          child: (item.author.avatarUrl ?? '').isEmpty
              ? Icon(Icons.person, size: isReply ? 16 : 18, color: Colors.black45)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(12, 10, hasMenu ? 4 : 12, 10),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? const Color(0xFFE8F4FD)
                      : const Color(0xFFF6F6F6),
                  borderRadius: BorderRadius.circular(14),
                  border: isHighlighted
                      ? Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.35))
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: name | time | edited badge | menu
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.author.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.appText.labelLarge!.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTime(item.createdAt),
                          style: context.appText.labelMedium!.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                        if (item.isEdited) ...[
                          const SizedBox(width: 3),
                          Text(
                            '· edited',
                            style: context.appText.labelSmall!.copyWith(
                              color: Colors.black38,
                            ),
                          ),
                        ],
                        if (hasMenu)
                          _CommentMenu(onEdit: onEdit, onDelete: onDelete),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.text,
                      style: context.appText.bodyMedium!.copyWith(height: 1.35),
                    ),
                    // Attachment image
                    if ((item.attachmentUrl ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: item.attachmentUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            height: 120,
                            color: const Color(0xFFE0E0E0),
                          ),
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 5),
              // Action row: like | reply | reply-count | spacer | report
              Row(
                children: [
                  _LikeButton(item: item, onTap: onLike, context: context),
                  const SizedBox(width: 8),
                  _ActionLabel(label: 'Reply', onTap: onReply, context: context),
                  if (item.replyCount > 0) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        '${item.replyCount} ${item.replyCount == 1 ? 'reply' : 'replies'}',
                        style: context.appText.labelSmall!.copyWith(
                          color: Colors.black38,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (!hasMenu && onReport != null)
                    _ActionLabel(
                      label: 'Report',
                      onTap: onReport!,
                      context: context,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LikeButton extends StatelessWidget {
  final PostCommentModel item;
  final VoidCallback onTap;
  final BuildContext context;

  const _LikeButton({
    required this.item,
    required this.onTap,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.isLikedByMe ? Icons.favorite : Icons.favorite_border,
              size: 15,
              color: item.isLikedByMe
                  ? context.colorScheme.primary
                  : Colors.black54,
            ),
            const SizedBox(width: 3),
            Text(
              '${item.likeCount}',
              style: context.appText.bodySmall!.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final BuildContext context;

  const _ActionLabel({
    required this.label,
    required this.onTap,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: context.appText.labelMedium!.copyWith(
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CommentMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CommentMenu({this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 28,
      child: PopupMenuButton<_CommentAction>(
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: const Icon(Icons.more_horiz, color: Colors.black38, size: 18),
        splashRadius: 14,
        onSelected: (action) {
          if (action == _CommentAction.edit) onEdit?.call();
          if (action == _CommentAction.delete) onDelete?.call();
        },
        itemBuilder: (_) => [
          if (onEdit != null)
            const PopupMenuItem(
              value: _CommentAction.edit,
              height: 44,
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Edit'),
                ],
              ),
            ),
          if (onDelete != null)
            const PopupMenuItem(
              value: _CommentAction.delete,
              height: 44,
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _CommentAction { edit, delete }
