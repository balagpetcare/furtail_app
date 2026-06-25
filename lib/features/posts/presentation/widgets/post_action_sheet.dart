import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/presentation/widgets/report_bottom_sheet.dart';
import 'package:furtail_app/services/social_service.dart';

/// Consistent, context-aware action sheet for posts.
///
/// Own post:    edit, delete, save/unsave, copy link.
/// Others:      save/unsave, follow/unfollow, share, copy link,
///              report (disabled if already reported), hide, block, view full post.
///
/// Always open via [PostActionSheet.show] so outer-context callbacks are
/// wired correctly before the sheet's own context is inflated.
class PostActionSheet extends StatefulWidget {
  final PostModel post;
  final bool isOwn;

  // Callbacks executed after the sheet is dismissed.
  // The parent provides these; they capture the parent's BuildContext.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onHide;
  final VoidCallback? onBlock;
  final VoidCallback? onViewFullPost;

  // Context-dependent callbacks built by show() from the caller's context.
  final VoidCallback? _onShareExternal;
  final Future<void> Function()? _onCopyLink;
  final VoidCallback? _onOpenReport;

  // Propagate state changes back to the parent screen.
  final void Function(PostModel updated)? onPostChanged;

  const PostActionSheet._({
    required this.post,
    required this.isOwn,
    this.onEdit,
    this.onDelete,
    this.onHide,
    this.onBlock,
    this.onViewFullPost,
    required VoidCallback? onShareExternal,
    required Future<void> Function()? onCopyLink,
    required VoidCallback? onOpenReport,
    this.onPostChanged,
  })  : _onShareExternal = onShareExternal,
        _onCopyLink = onCopyLink,
        _onOpenReport = onOpenReport;

  /// Primary entry point. Wires context-dependent callbacks using [context]
  /// from the calling widget, which remains valid after the sheet is dismissed.
  static Future<void> show(
    BuildContext context, {
    required PostModel post,
    required bool isOwn,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onHide,
    VoidCallback? onBlock,
    VoidCallback? onViewFullPost,
    void Function(PostModel updated)? onPostChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PostActionSheet._(
        post: post,
        isOwn: isOwn,
        onEdit: onEdit,
        onDelete: onDelete,
        onHide: onHide,
        onBlock: onBlock,
        onViewFullPost: onViewFullPost,
        onPostChanged: onPostChanged,
        onShareExternal: () {
          final fundraisingId = post.fundraisingCampaignId;
          if (fundraisingId != null) {
            ShareService.share(context, type: 'fundraising', id: fundraisingId);
          } else {
            ShareService.share(context, type: 'post', id: post.id);
          }
          // Record share on backend (fire-and-forget).
          PostsRemoteDs().sharePost(post.id).catchError((_) => <String, dynamic>{});
        },
        onCopyLink: () async {
          final link = 'https://furtail.app/post/${post.id}';
          await Clipboard.setData(ClipboardData(text: link));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link copied to clipboard')),
          );
        },
        onOpenReport: () =>
            ReportBottomSheet.showPost(context, postId: post.id),
      ),
    );
  }

  @override
  State<PostActionSheet> createState() => _PostActionSheetState();
}

class _PostActionSheetState extends State<PostActionSheet> {
  late bool _isBookmarked;
  late bool _isFollowing;
  late bool _isReported;
  bool _bookmarkLoading = false;
  bool _followLoading = false;

  final _ds = PostsRemoteDs();
  final _social = SocialService();

  @override
  void initState() {
    super.initState();
    _isBookmarked = widget.post.isBookmarkedByMe;
    _isFollowing = widget.post.isFollowingAuthor;
    _isReported = widget.post.isReportedByMe;
  }

  // ── State helpers ──────────────────────────────────────────────────────────

  void _emit({bool? bookmarked, bool? following, bool? reported}) {
    widget.onPostChanged?.call(
      widget.post.copyWith(
        isBookmarkedByMe: bookmarked ?? _isBookmarked,
        isFollowingAuthor: following ?? _isFollowing,
        isReportedByMe: reported ?? _isReported,
      ),
    );
  }

  // ── Dismiss helpers ────────────────────────────────────────────────────────

  void _dismissThen(VoidCallback? after) {
    Navigator.pop(context);
    if (after != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => after());
    }
  }

  void _dismissThenAsync(Future<void> Function()? after) {
    Navigator.pop(context);
    if (after != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => after());
    }
  }

  // ── Bookmark ───────────────────────────────────────────────────────────────

  Future<void> _toggleBookmark() async {
    if (_bookmarkLoading) return;
    final next = !_isBookmarked;
    setState(() {
      _isBookmarked = next;
      _bookmarkLoading = true;
    });
    try {
      if (next) {
        await _ds.bookmarkPost(postId: widget.post.id);
      } else {
        await _ds.unbookmarkPost(postId: widget.post.id);
      }
      _emit(bookmarked: next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next ? 'Post saved 🐾' : 'Removed from Saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBookmarked = !next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _bookmarkLoading = false);
    }
  }

  // ── Follow ─────────────────────────────────────────────────────────────────

  Future<void> _toggleFollow() async {
    if (_followLoading) return;
    final next = !_isFollowing;
    setState(() {
      _isFollowing = next;
      _followLoading = true;
    });
    try {
      if (next) {
        await _social.follow(widget.post.author.id);
      } else {
        await _social.unfollow(widget.post.author.id);
      }
      _emit(following: next);
      if (!mounted) return;
      final name = widget.post.author.name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next ? 'Following $name' : 'Unfollowed $name'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFollowing = !next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Follow failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  // ── Report ─────────────────────────────────────────────────────────────────

  void _tapReport() {
    if (_isReported) return;
    // Mark optimistically before dismissal so the parent gets the updated state.
    _emit(reported: true);
    _dismissThen(widget._onOpenReport);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          if (widget.isOwn) ..._buildOwnItems(context),
          if (!widget.isOwn) ..._buildOtherItems(context),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  List<Widget> _buildOwnItems(BuildContext context) {
    return [
      if (widget.onEdit != null)
        _ActionTile(
          icon: Icons.edit_outlined,
          label: 'Edit post',
          onTap: () => _dismissThen(widget.onEdit),
        ),
      if (widget.onDelete != null)
        _ActionTile(
          icon: Icons.delete_outline,
          label: 'Delete post',
          color: Theme.of(context).colorScheme.error,
          onTap: () => _dismissThen(widget.onDelete),
        ),
      _BookmarkTile(
        isBookmarked: _isBookmarked,
        loading: _bookmarkLoading,
        onTap: _toggleBookmark,
      ),
      _ActionTile(
        icon: Icons.link_rounded,
        label: 'Copy link',
        onTap: () => _dismissThenAsync(widget._onCopyLink),
      ),
      if (widget.onViewFullPost != null)
        _ActionTile(
          icon: Icons.open_in_new_outlined,
          label: 'View full post',
          onTap: () => _dismissThen(widget.onViewFullPost),
        ),
    ];
  }

  List<Widget> _buildOtherItems(BuildContext context) {
    final authorName = widget.post.author.name;
    return [
      _BookmarkTile(
        isBookmarked: _isBookmarked,
        loading: _bookmarkLoading,
        onTap: _toggleBookmark,
      ),
      _FollowTile(
        authorName: authorName,
        isFollowing: _isFollowing,
        loading: _followLoading,
        onTap: _toggleFollow,
      ),
      _ActionTile(
        icon: Icons.share_outlined,
        label: 'Share',
        onTap: () => _dismissThen(widget._onShareExternal),
      ),
      _ActionTile(
        icon: Icons.link_rounded,
        label: 'Copy link',
        onTap: () => _dismissThenAsync(widget._onCopyLink),
      ),
      _ActionTile(
        icon: _isReported ? Icons.flag_rounded : Icons.flag_outlined,
        label: _isReported ? 'Already reported' : 'Report',
        color: _isReported ? Colors.black38 : null,
        enabled: !_isReported,
        onTap: _isReported ? null : _tapReport,
      ),
      if (widget.onHide != null)
        _ActionTile(
          icon: Icons.visibility_off_outlined,
          label: 'Hide post',
          onTap: () => _dismissThen(widget.onHide),
        ),
      if (widget.onBlock != null)
        _ActionTile(
          icon: Icons.block_outlined,
          label: 'Block $authorName',
          color: Theme.of(context).colorScheme.error,
          onTap: () => _dismissThen(widget.onBlock),
        ),
      if (widget.onViewFullPost != null)
        _ActionTile(
          icon: Icons.open_in_new_outlined,
          label: 'View full post',
          onTap: () => _dismissThen(widget.onViewFullPost),
        ),
    ];
  }
}

// ── Shared tile widgets ───────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool enabled;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.color,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled
        ? (color ?? Theme.of(context).colorScheme.onSurface)
        : Colors.black38;
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, size: 22, color: effectiveColor),
      title: Text(
        label,
        style: TextStyle(
          color: effectiveColor,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      onTap: enabled ? onTap : null,
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  final bool isBookmarked;
  final bool loading;
  final VoidCallback onTap;

  const _BookmarkTile({
    required this.isBookmarked,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
              size: 22,
              color: Theme.of(context).colorScheme.onSurface,
            ),
      title: Text(
        isBookmarked ? 'Remove from Saved' : 'Save post',
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      onTap: loading ? null : onTap,
    );
  }
}

class _FollowTile extends StatelessWidget {
  final String authorName;
  final bool isFollowing;
  final bool loading;
  final VoidCallback onTap;

  const _FollowTile({
    required this.authorName,
    required this.isFollowing,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              isFollowing
                  ? Icons.person_remove_outlined
                  : Icons.person_add_outlined,
              size: 22,
              color: Theme.of(context).colorScheme.onSurface,
            ),
      title: Text(
        isFollowing ? 'Unfollow $authorName' : 'Follow $authorName',
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      onTap: loading ? null : onTap,
    );
  }
}
