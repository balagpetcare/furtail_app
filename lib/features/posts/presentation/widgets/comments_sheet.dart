import 'package:furtail_app/core/analytics/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_comment_model.dart';

class CommentsSheet extends StatefulWidget {
  final int postId;
  final void Function(int newCount)? onCountChanged;
  /// If true, focuses the composer text field right after the sheet opens.
  final bool autoFocusComposer;

  const CommentsSheet({
    super.key,
    required this.postId,
    this.onCountChanged,
    this.autoFocusComposer = false,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _ds = PostsRemoteDs();
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  bool _loading = true;
  bool _sending = false;
  List<PostCommentModel> _items = const [];

  int? _replyToCommentId;
  String? _replyToName;

  String? _myAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _load();

    if (widget.autoFocusComposer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focus.requestFocus();
      });
    }
  }

  Future<void> _loadMe() async {
    final sp = await SharedPreferences.getInstance();
    final a = (sp.getString('avatarUrl') ?? '').trim();
    if (!mounted) return;
    setState(() => _myAvatarUrl = a.isEmpty ? null : a);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _ds.listComments(widget.postId);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
      widget.onCountChanged?.call(_items.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _setReplyTarget(PostCommentModel c) {
    setState(() {
      _replyToCommentId = c.id;
      _replyToName = c.author.name;
    });
    _focus.requestFocus();
  }

  void _clearReplyTarget() {
    setState(() {
      _replyToCommentId = null;
      _replyToName = null;
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final int? replyTo = _replyToCommentId;
      final created = replyTo == null
          ? await _ds.addComment(widget.postId, text)
          : await _ds.replyComment(postId: widget.postId, commentId: replyTo, text: text);

      await AnalyticsService.instance.logCommentCreated(
        postId: widget.postId,
        commentId: created.id,
        isReply: replyTo != null,
      );
      if (!mounted) return;
      setState(() {
        _items = [created, ..._items];
        _sending = false;
        _ctrl.clear();
        _replyToCommentId = null;
        _replyToName = null;
      });
      widget.onCountChanged?.call(_items.length);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _toggleLike(PostCommentModel c) async {
    // optimistic
    final idx = _items.indexWhere((x) => x.id == c.id);
    if (idx < 0) return;
    final currently = _items[idx].isLikedByMe;
    setState(() {
      _items = List<PostCommentModel>.from(_items);
      _items[idx] = _items[idx].copyWith(
        isLikedByMe: !currently,
        likeCount: (_items[idx].likeCount + (currently ? -1 : 1)).clamp(0, 1 << 30),
      );
    });

    try {
      final res = currently
          ? await _ds.unlikeComment(postId: widget.postId, commentId: c.id)
          : await _ds.likeComment(postId: widget.postId, commentId: c.id);
      final likeCount = (res['likeCount'] as num?)?.toInt();
      if (likeCount != null && mounted) {
        final idx2 = _items.indexWhere((x) => x.id == c.id);
        if (idx2 >= 0) {
          setState(() {
            _items = List<PostCommentModel>.from(_items);
            _items[idx2] = _items[idx2].copyWith(likeCount: likeCount, isLikedByMe: !currently);
          });
        }
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final topLevel = _items.where((c) => c.parentId == null).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final repliesByParent = <int, List<PostCommentModel>>{};
    for (final c in _items) {
      final pid = c.parentId;
      if (pid == null) continue;
      repliesByParent.putIfAbsent(pid, () => []).add(c);
    }

    for (final e in repliesByParent.entries) {
      e.value.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    // ✅ Keyboard-safe: when the user taps "Write comment" and keyboard opens,
    // keep the composer visible above the keyboard (no overlap).
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
          children: [
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  Text('Comments', style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 6),

// Composer (top, always visible while scrolling)
_Composer(
  myAvatarUrl: _myAvatarUrl,
  replyingToName: _replyToName,
  onCancelReply: _clearReplyTarget,
  controller: _ctrl,
  focusNode: _focus,
  sending: _sending,
  onSend: _send,
),

Expanded(
  child: _loading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            itemCount: topLevel.length,
            itemBuilder: (_, i) {
              final parent = topLevel[i];
              final replies = repliesByParent[parent.id] ?? const [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CommentTile(
                    item: parent,
                    isReply: false,
                    onLike: () => _toggleLike(parent),
                    onReply: () => _setReplyTarget(parent),
                  ),
                  for (final r in replies)
                    Padding(
                      padding: const EdgeInsets.only(left: 42, top: 8),
                      child: _CommentTile(
                        item: r,
                        isReply: true,
                        onLike: () => _toggleLike(r),
                        onReply: () => _setReplyTarget(parent),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
),
          ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final String? myAvatarUrl;
  final String? replyingToName;
  final VoidCallback onCancelReply;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({
    required this.myAvatarUrl,
    required this.replyingToName,
    required this.onCancelReply,
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.06))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((replyingToName ?? '').isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F6F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to $replyingToName',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: onCancelReply,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  )
                ],
              ),
            ),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEFEFEF),
                backgroundImage: (myAvatarUrl ?? '').isEmpty ? null : NetworkImage(myAvatarUrl!),
                child: (myAvatarUrl ?? '').isEmpty ? const Icon(Icons.person, size: 18, color: Colors.black45) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: replyingToName == null ? 'Write a comment…' : 'Write a reply…',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
              ),
            ],
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

class _CommentTile extends StatelessWidget {
  final PostCommentModel item;
  final bool isReply;
  final VoidCallback onLike;
  final VoidCallback onReply;

  const _CommentTile({
    required this.item,
    required this.isReply,
    required this.onLike,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: isReply ? 16 : 18,
          backgroundColor: const Color(0xFFEFEFEF),
          backgroundImage: (item.author.avatarUrl ?? '').isEmpty ? null : NetworkImage(item.author.avatarUrl!),
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
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.author.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.appText.labelLarge!.copyWith(fontWeight: FontWeight.w900),
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
                    Text(item.text, style: const TextStyle(height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  InkWell(
                    onTap: onLike,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        children: [
                          Icon(item.isLikedByMe ? Icons.favorite : Icons.favorite_border, size: 16, color: item.isLikedByMe ? context.colorScheme.primary : Colors.black54),
                          const SizedBox(width: 4),
                          Text('${item.likeCount}', style: context.appText.bodySmall!.copyWith(color: Colors.black54)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: onReply,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text('Reply', style: context.appText.labelMedium!.copyWith(color: Colors.black54, fontWeight: FontWeight.w700)),
                    ),
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
