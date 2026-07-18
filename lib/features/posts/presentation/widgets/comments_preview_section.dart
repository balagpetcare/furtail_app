import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/app_typography.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_comment_model.dart';

/// Inline preview of the latest comments for a post.
///
/// Shows [previewCount] comments (including replies if returned by API),
/// then renders a "View all comments" CTA.
class CommentsPreviewSection extends StatefulWidget {
  final int postId;
  final int previewCount;
  final int totalCount;
  final int reloadToken;
  final VoidCallback onViewAll;
  final bool showTitle;

  const CommentsPreviewSection({
    super.key,
    required this.postId,
    this.previewCount = 20,
    required this.totalCount,
    this.reloadToken = 0,
    required this.onViewAll,
    this.showTitle = true,
  });

  @override
  State<CommentsPreviewSection> createState() => _CommentsPreviewSectionState();
}

class _CommentsPreviewSectionState extends State<CommentsPreviewSection> {
  final ds = PostsRemoteDs();
  int _localReload = 0;

  void _bumpReload() => setState(() => _localReload++);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showTitle) ...[
            Text(
              'Comments',
              style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
          ],
          FutureBuilder<List<PostCommentModel>>(
            key: ValueKey('${widget.reloadToken}-$_localReload'),
            future: ds.listComments(
              widget.postId,
              limit: widget.previewCount,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text('No comments yet', style: TextStyle(color: Colors.black54)),
                );
              }

              final topLevel = list.where((c) => c.parentId == null).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              final repliesByParent = <int, List<PostCommentModel>>{};
              for (final c in list) {
                final pid = c.parentId;
                if (pid == null) continue;
                repliesByParent.putIfAbsent(pid, () => []).add(c);
              }
              for (final e in repliesByParent.entries) {
                e.value.sort((a, b) => a.createdAt.compareTo(b.createdAt));
              }

              return Column(
                children: [
                  for (final parent in topLevel) ...[
                    _MiniCommentTile(
                      item: parent,
                      isReply: false,
                      postId: widget.postId,
                      onChanged: _bumpReload,
                    ),
                    for (final r in (repliesByParent[parent.id] ?? const []))
                      Padding(
                        padding: const EdgeInsets.only(left: 40, top: 8),
                        child: _MiniCommentTile(
                          item: r,
                          isReply: true,
                          postId: widget.postId,
                          onChanged: _bumpReload,
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
          if (widget.totalCount > 20)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onViewAll,
                child: Text('View all comments (${widget.totalCount})'),
              ),
            ),
        ],
      ),
    );
  }
}


String _formatCommentTime(DateTime dt) {
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

class _MiniCommentTile extends StatelessWidget {
  final PostCommentModel item;
  final bool isReply;
  final int postId;
  final VoidCallback onChanged;

  const _MiniCommentTile({
    required this.item,
    required this.isReply,
    required this.postId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ds = PostsRemoteDs();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FurtailNetworkAvatar(
          imageUrl: item.author.avatarUrl,
          displayName: item.author.name,
          radius: isReply ? 12 : 14,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      item.author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.menuTitle(context).copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatCommentTime(item.createdAt),
                    style: context.appText.labelMedium!.copyWith(color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.text,
                style: const TextStyle(color: Colors.black87, height: 1.35),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MiniAction(
                    label: item.isLikedByMe ? 'Liked' : 'Like',
                    selected: item.isLikedByMe,
                    onTap: () async {
                      try {
                        if (item.isLikedByMe) {
                          await ds.unlikeComment(postId: postId, commentId: item.id);
                        } else {
                          await ds.likeComment(postId: postId, commentId: item.id);
                        }
                        onChanged();
                      } catch (_) {}
                    },
                  ),
                  Text(
                    '${item.likeCount} likes',
                    style: context.appText.labelMedium!.copyWith(color: Colors.black54),
                  ),
                  if (!isReply)
                    _MiniAction(
                      label: 'Reply',
                      onTap: () async {
                        final ctrl = TextEditingController();
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Reply'),
                            content: TextField(
                              controller: ctrl,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Write a reply…',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Reply'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          final text = ctrl.text.trim();
                          if (text.isEmpty) return;
                          try {
                            await ds.addReply(postId: postId, commentId: item.id, text: text);
                            onChanged();
                          } catch (_) {}
                        }
                      },
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

class _MiniAction extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MiniAction({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: context.appText.labelMedium!.copyWith(
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            color: selected ? context.colorScheme.primary : Colors.black54,
          ),
        ),
      ),
    );
  }
}
