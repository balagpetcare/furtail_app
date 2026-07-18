import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_comment_model.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/services/api_client.dart';

Future<void> showAdoptionCommentsSheet(
  BuildContext context, {
  required AdoptionPetUiModel pet,
  AdoptionRepository? repository,
  void Function(int newCount)? onCountChanged,
}) {
  final repo = repository ?? AdoptionRepository(AdoptionRemoteDs(ApiClient()));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AdoptionCommentsSheet(
      pet: pet,
      repository: repo,
      onCountChanged: onCountChanged,
    ),
  );
}

class _AdoptionCommentsSheet extends StatefulWidget {
  final AdoptionPetUiModel pet;
  final AdoptionRepository repository;
  final void Function(int newCount)? onCountChanged;

  const _AdoptionCommentsSheet({
    required this.pet,
    required this.repository,
    required this.onCountChanged,
  });

  @override
  State<_AdoptionCommentsSheet> createState() => _AdoptionCommentsSheetState();
}

class _AdoptionCommentsSheetState extends State<_AdoptionCommentsSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  bool _loading = true;
  bool _sending = false;
  bool _error = false;
  bool _guest = true;
  int _commentCount = 0;
  int? _myUserId;
  List<AdoptionCommentModel> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSession = await SecureStorageService().hasSession;
    if (!mounted) return;
    setState(() {
      _myUserId = prefs.getInt('userId');
      _guest = !hasSession;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final response = await widget.repository.fetchAdoptionComments(
        widget.pet.id,
        limit: 100,
      );
      final items = (response['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdoptionCommentModel.fromJson)
          .toList();
      final meta = (response['meta'] as Map<String, dynamic>?) ?? const {};
      final count = (meta['commentCount'] as num?)?.toInt() ?? items.length;

      if (!mounted) return;
      setState(() {
        _items = items;
        _commentCount = count;
        _loading = false;
      });
      widget.onCountChanged?.call(count);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _send() async {
    if (_guest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to add a comment.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final created = await widget.repository.addAdoptionComment(
        widget.pet.id,
        text,
      );
      if (!mounted) return;
      setState(() {
        _items = [created, ..._items];
        _commentCount += 1;
        _sending = false;
      });
      _controller.clear();
      widget.onCountChanged?.call(_commentCount);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not add comment.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteComment(AdoptionCommentModel comment) async {
    if (_sending) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _sending = true);
    try {
      await widget.repository.deleteAdoptionComment(widget.pet.id, comment.id);
      if (!mounted) return;
      setState(() {
        _items = _items.where((item) => item.id != comment.id).toList();
        _commentCount = _commentCount > 0 ? _commentCount - 1 : 0;
        _sending = false;
      });
      widget.onCountChanged?.call(_commentCount);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete comment.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Material(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.9,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comments',
                              style: AppTypography.sectionTitle(
                                context,
                              ).copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.pet.name} | $_commentCount ${_commentCount == 1 ? 'comment' : 'comments'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption(
                                context,
                              ).copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (_loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error)
                  Expanded(
                    child: _StateMessage(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load comments',
                      message:
                          'Pull down or tap retry to load the thread again.',
                      actionLabel: 'Retry',
                      onAction: _load,
                    ),
                  )
                else if (_items.isEmpty)
                  Expanded(
                    child: _StateMessage(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No comments yet',
                      message: _guest
                          ? 'Sign in to start the conversation.'
                          : 'Be the first to comment on this listing.',
                    ),
                  )
                else
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final comment = _items[index];
                          final isMine =
                              _myUserId != null &&
                              comment.author.id == _myUserId;
                          final canDelete = comment.canDelete || isMine;
                          return _AdoptionCommentTile(
                            comment: comment,
                            canDelete: canDelete,
                            onDelete: canDelete
                                ? () => _deleteComment(comment)
                                : null,
                          );
                        },
                      ),
                    ),
                  ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: _Composer(
                    controller: _controller,
                    sending: _sending,
                    guest: _guest,
                    onSend: _send,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool guest;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.guest,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (guest)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              'Sign in to add a comment.',
              style: AppTypography.bodyRegular(
                context,
              ).copyWith(color: cs.onSurfaceVariant),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Write a comment...',
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
              FilledButton(
                onPressed: sending ? null : onSend,
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
      ],
    );
  }
}

class _AdoptionCommentTile extends StatelessWidget {
  final AdoptionCommentModel comment;
  final bool canDelete;
  final VoidCallback? onDelete;

  const _AdoptionCommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 4) return '${weeks}w';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '${months}mo';
    return '${(diff.inDays / 365).floor()}y';
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: cs.surfaceContainerHighest,
            backgroundImage: (comment.author.avatarUrl ?? '').isEmpty
                ? null
                : NetworkImage(comment.author.avatarUrl!),
            child: (comment.author.avatarUrl ?? '').isEmpty
                ? Icon(Icons.pets_rounded, size: 18, color: cs.onSurfaceVariant)
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.author.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyRegular(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment.createdAt),
                      style: AppTypography.caption(
                        context,
                      ).copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (canDelete)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        onSelected: (value) {
                          if (value == 'delete') onDelete?.call();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: AppTypography.bodyRegular(
                    context,
                  ).copyWith(color: cs.onSurface, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.sectionTitle(
                context,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyRegular(
                context,
              ).copyWith(color: cs.onSurfaceVariant),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
