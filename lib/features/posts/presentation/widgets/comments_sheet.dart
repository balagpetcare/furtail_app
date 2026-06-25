import 'package:furtail_app/core/analytics/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_comment_model.dart';
import 'package:furtail_app/features/posts/presentation/widgets/comment_tile.dart';
import 'package:furtail_app/features/posts/presentation/widgets/report_bottom_sheet.dart';

class CommentsSheet extends StatefulWidget {
  final int postId;
  final void Function(int newCount)? onCountChanged;
  final bool autoFocusComposer;

  /// When provided, the matching comment is visually highlighted after load.
  final int? highlightCommentId;

  const CommentsSheet({
    super.key,
    required this.postId,
    this.onCountChanged,
    this.autoFocusComposer = false,
    this.highlightCommentId,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _ds = PostsRemoteDs();
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _scrollController = ScrollController();

  // Comment list state
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _error = false;
  List<PostCommentModel> _items = const [];
  String? _nextCursor;

  // Current-user state
  String? _myAvatarUrl;
  int? _myUserId;

  // Composer mode: reply
  int? _replyToCommentId;
  String? _replyToName;

  // Composer mode: edit (mutually exclusive with reply)
  int? _editingCommentId;

  // GlobalKey per comment for highlight scrolling
  final _commentKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _loadMe();
    _load();
    _scrollController.addListener(_onScroll);

    if (widget.autoFocusComposer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  Future<void> _loadMe() async {
    final sp = await SharedPreferences.getInstance();
    final a = (sp.getString('avatarUrl') ?? '').trim();
    final uid = sp.getInt('userId');
    if (!mounted) return;
    setState(() {
      _myAvatarUrl = a.isEmpty ? null : a;
      _myUserId = uid;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 250) {
      _loadMore();
    }
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
      _nextCursor = null;
      _hasMore = false;
      _items = const [];
    });

    try {
      // Attempt cursor-paginated fetch (preferred)
      final result = await _ds.listCommentsCursor(widget.postId, limit: 30);
      final newItems = (result['items'] as List).cast<PostCommentModel>();
      final nextCursor = result['nextCursor'] as String?;
      if (!mounted) return;
      setState(() {
        _items = newItems;
        _nextCursor = nextCursor;
        _hasMore = nextCursor != null && nextCursor.isNotEmpty;
        _loading = false;
      });
      widget.onCountChanged?.call(_items.length);
      _maybeScrollToHighlight();
    } catch (_) {
      // Fallback: flat list fetch (backend may not support cursor response format)
      try {
        final list = await _ds.listComments(widget.postId);
        if (!mounted) return;
        setState(() {
          _items = list;
          _hasMore = false;
          _loading = false;
        });
        widget.onCountChanged?.call(_items.length);
        _maybeScrollToHighlight();
      } catch (e2) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _nextCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _ds.listCommentsCursor(
        widget.postId,
        limit: 30,
        cursor: _nextCursor,
      );
      final newItems = (result['items'] as List).cast<PostCommentModel>();
      final nextCursor = result['nextCursor'] as String?;
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...newItems];
        _nextCursor = nextCursor;
        _hasMore = nextCursor != null && nextCursor.isNotEmpty;
        _loadingMore = false;
      });
      widget.onCountChanged?.call(_items.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _maybeScrollToHighlight() {
    final id = widget.highlightCommentId;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _commentKeys[id];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          alignment: 0.25,
        );
      }
    });
  }

  // ── Reply ──────────────────────────────────────────────────────────────────

  void _setReplyTarget(PostCommentModel c) {
    setState(() {
      _replyToCommentId = c.id;
      _replyToName = c.author.name;
      _editingCommentId = null;
    });
    _ctrl.clear();
    _focus.requestFocus();
  }

  void _clearReplyTarget() {
    setState(() {
      _replyToCommentId = null;
      _replyToName = null;
    });
  }

  // ── Edit ───────────────────────────────────────────────────────────────────

  void _startEdit(PostCommentModel c) {
    setState(() {
      _editingCommentId = c.id;
      _replyToCommentId = null;
      _replyToName = null;
    });
    _ctrl.text = c.text;
    _ctrl.selection =
        TextSelection.fromPosition(TextPosition(offset: c.text.length));
    _focus.requestFocus();
  }

  void _cancelEdit() {
    setState(() => _editingCommentId = null);
    _ctrl.clear();
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _deleteComment(PostCommentModel c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _ds.deleteComment(postId: widget.postId, commentId: c.id);
      if (!mounted) return;
      setState(() {
        _items = _items.where((x) => x.id != c.id).toList();
      });
      widget.onCountChanged?.call(_items.length);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: ${e.toString()}')),
      );
    }
  }

  // ── Send / Edit submit ─────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);

    if (_editingCommentId != null) {
      await _submitEdit(text);
      return;
    }

    try {
      final int? replyTo = _replyToCommentId;
      final created = replyTo == null
          ? await _ds.addComment(widget.postId, text)
          : await _ds.replyComment(
              postId: widget.postId,
              commentId: replyTo,
              text: text,
            );

      await AnalyticsService.instance.logCommentCreated(
        postId: widget.postId,
        commentId: created.id,
        isReply: replyTo != null,
      );
      if (!mounted) return;
      setState(() {
        _items = [created, ..._items];
        _sending = false;
        _replyToCommentId = null;
        _replyToName = null;
      });
      _ctrl.clear();
      widget.onCountChanged?.call(_items.length);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment failed: ${e.toString()}')),
      );
    }
  }

  bool _sending = false;

  Future<void> _submitEdit(String text) async {
    final commentId = _editingCommentId!;
    try {
      final updated = await _ds.editComment(
        postId: widget.postId,
        commentId: commentId,
        text: text,
      );
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((x) => x.id == commentId);
        if (idx >= 0) {
          final newList = List<PostCommentModel>.from(_items);
          newList[idx] = updated;
          _items = newList;
        }
        _sending = false;
        _editingCommentId = null;
      });
      _ctrl.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Edit failed: ${e.toString()}')),
      );
    }
  }

  // ── Like ───────────────────────────────────────────────────────────────────

  Future<void> _toggleLike(PostCommentModel c) async {
    final idx = _items.indexWhere((x) => x.id == c.id);
    if (idx < 0) return;
    final currently = _items[idx].isLikedByMe;
    setState(() {
      final newList = List<PostCommentModel>.from(_items);
      newList[idx] = newList[idx].copyWith(
        isLikedByMe: !currently,
        likeCount:
            (_items[idx].likeCount + (currently ? -1 : 1)).clamp(0, 1 << 30),
      );
      _items = newList;
    });

    try {
      final res = currently
          ? await _ds.unlikeComment(postId: widget.postId, commentId: c.id)
          : await _ds.likeComment(postId: widget.postId, commentId: c.id);
      final likeCount = (res['likeCount'] as num?)?.toInt();
      if (likeCount != null && mounted) {
        final idx2 = _items.indexWhere((x) => x.id == c.id);
        if (idx2 >= 0) {
          final newList = List<PostCommentModel>.from(_items);
          newList[idx2] =
              newList[idx2].copyWith(likeCount: likeCount, isLikedByMe: !currently);
          setState(() => _items = newList);
        }
      }
    } catch (_) {
      // optimistic already applied — ignore server error
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Tree: group replies under parents
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

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Comments',
                      style: context.appText.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (_items.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${_items.length}',
                        style: context.appText.bodyMedium!.copyWith(
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Composer (always visible)
              _Composer(
                myAvatarUrl: _myAvatarUrl,
                replyingToName: _replyToName,
                onCancelReply: _clearReplyTarget,
                editingMode: _editingCommentId != null,
                onCancelEdit: _cancelEdit,
                controller: _ctrl,
                focusNode: _focus,
                sending: _sending,
                onSend: _send,
              ),

              // Body: loading / error / empty / list
              if (_error)
                _ErrorState(onRetry: _load)
              else if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (topLevel.isEmpty)
                const _EmptyState()
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding:
                          const EdgeInsets.fromLTRB(14, 10, 14, 24),
                      itemCount: topLevel.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        // Loading-more spinner at the end
                        if (i == topLevel.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        final parent = topLevel[i];
                        final replies =
                            repliesByParent[parent.id] ?? const [];
                        final pKey = _commentKeys.putIfAbsent(
                          parent.id,
                          () => GlobalKey(),
                        );
                        final isOwn = _myUserId != null &&
                            parent.author.id == _myUserId;

                        return Column(
                          key: pKey,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CommentTile(
                              item: parent,
                              isReply: false,
                              isHighlighted:
                                  widget.highlightCommentId == parent.id,
                              onLike: () => _toggleLike(parent),
                              onReply: () => _setReplyTarget(parent),
                              onReport: isOwn
                                  ? null
                                  : () => ReportBottomSheet.show(
                                        context,
                                        targetType: ReportTargetType.comment,
                                        targetId: parent.id,
                                      ),
                              onEdit: isOwn
                                  ? () => _startEdit(parent)
                                  : null,
                              onDelete: isOwn
                                  ? () => _deleteComment(parent)
                                  : null,
                            ),
                            for (final r in replies)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 42,
                                  top: 8,
                                ),
                                child: CommentTile(
                                  item: r,
                                  isReply: true,
                                  isHighlighted:
                                      widget.highlightCommentId == r.id,
                                  onLike: () => _toggleLike(r),
                                  onReply: () => _setReplyTarget(parent),
                                  onReport: (_myUserId != null &&
                                          r.author.id == _myUserId)
                                      ? null
                                      : () => ReportBottomSheet.show(
                                            context,
                                            targetType:
                                                ReportTargetType.comment,
                                            targetId: r.id,
                                          ),
                                  onEdit: (_myUserId != null &&
                                          r.author.id == _myUserId)
                                      ? () => _startEdit(r)
                                      : null,
                                  onDelete: (_myUserId != null &&
                                          r.author.id == _myUserId)
                                      ? () => _deleteComment(r)
                                      : null,
                                ),
                              ),
                            const SizedBox(height: 14),
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

// ── Composer ─────────────────────────────────────────────────────────────────

class _Composer extends StatelessWidget {
  final String? myAvatarUrl;
  final String? replyingToName;
  final VoidCallback onCancelReply;
  final bool editingMode;
  final VoidCallback? onCancelEdit;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({
    required this.myAvatarUrl,
    required this.replyingToName,
    required this.onCancelReply,
    required this.editingMode,
    required this.onCancelEdit,
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final showReplyBanner =
        !editingMode && (replyingToName ?? '').isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Edit banner
          if (editingMode)
            _BannerChip(
              icon: Icons.edit_outlined,
              label: 'Editing comment',
              onCancel: onCancelEdit,
              color: const Color(0xFFE8F4FD),
              iconColor: const Color(0xFF1976D2),
            ),
          // Reply banner
          if (showReplyBanner)
            _BannerChip(
              icon: Icons.reply_rounded,
              label: 'Replying to $replyingToName',
              onCancel: onCancelReply,
              color: const Color(0xFFF6F6F6),
              iconColor: Colors.black54,
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEFEFEF),
                backgroundImage: (myAvatarUrl ?? '').isEmpty
                    ? null
                    : NetworkImage(myAvatarUrl!),
                child: (myAvatarUrl ?? '').isEmpty
                    ? const Icon(Icons.person, size: 18, color: Colors.black45)
                    : null,
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
                    hintText: editingMode
                        ? 'Edit your comment…'
                        : (replyingToName != null
                            ? 'Write a reply…'
                            : 'Write a comment…'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        editingMode
                            ? Icons.check_rounded
                            : Icons.send_rounded,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onCancel;
  final Color color;
  final Color iconColor;

  const _BannerChip({
    required this.icon,
    required this.label,
    required this.onCancel,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption(context)
                  .copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onCancel != null)
            GestureDetector(
              onTap: onCancel,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 16, color: iconColor),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 52,
                color: Colors.black26,
              ),
              const SizedBox(height: 14),
              Text(
                'No comments yet',
                style: AppTypography.bodyLarge(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Be the first to comment!',
                style: AppTypography.caption(context).copyWith(
                  color: Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 52,
                color: Colors.black26,
              ),
              const SizedBox(height: 14),
              Text(
                'Could not load comments',
                style: AppTypography.bodyLarge(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
