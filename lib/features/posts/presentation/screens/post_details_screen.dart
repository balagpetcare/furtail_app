import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:furtail_app/app/router/app_routes.dart';
import 'package:furtail_app/core/navigation/profile_navigation.dart';
import 'package:furtail_app/core/storage/local_storage.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';

import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/presentation/widgets/comments_preview_section.dart';
import 'package:furtail_app/features/posts/presentation/widgets/comments_bottom_sheet.dart';
import 'package:furtail_app/features/posts/presentation/widgets/post_action_sheet.dart';
import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/features/posts/presentation/widgets/post_background_style.dart';
import 'package:furtail_app/features/posts/presentation/widgets/post_details_header.dart';
import 'package:furtail_app/features/posts/presentation/widgets/post_details_actions.dart';
import 'package:furtail_app/features/posts/presentation/widgets/post_media_carousel.dart';

/// Premium post details screen with Facebook-style social UX.
///
/// Layout:
///   AppBar (author header + more menu + share)
///   └─ Caption (with background style for short text posts)
///   └─ Media carousel (images/video)
///   └─ Inline Like / Comment / Share action row
///   └─ Comments preview section
///   Bottom bar: sticky comment composer (opens bottom sheet)
class PostDetailsScreen extends StatefulWidget {
  final PostModel post;
  const PostDetailsScreen({super.key, required this.post});

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  late PostModel _post;
  final _ds = PostsRemoteDs();
  int? _meId;
  String? _myAvatarUrl;
  final int _commentsReload = 0;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadMe();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadMe() async {
    final id = await LocalStorage.getUserId();
    final avatar = await LocalStorage.getAvatarUrl();
    if (!mounted) return;
    setState(() {
      _meId = id;
      _myAvatarUrl = avatar;
    });
  }

  bool get _canEdit => _meId != null && _post.author.id == _meId;

  bool _isBackgroundTextPost(PostModel post) {
    final caption = post.caption;
    if (caption == null || caption.isEmpty) return false;

    final styleId = post.backgroundStyle;
    return post.media.isEmpty &&
        caption.length <= 160 &&
        styleId != null &&
        styleId != 'none';
  }

  Future<void> _openEdit() async {
    if (!_canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only edit your own post.')),
      );
      return;
    }

    final updated = await Navigator.pushNamed(
      context,
      AppRoutes.postEdit,
      arguments: {'post': _post},
    );

    if (!mounted) return;
    if (updated is PostModel) {
      setState(() => _post = updated);
    }
  }

  Future<void> _deletePost() async {
    if (!_canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own post.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This will remove the post from the feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await _ds.deletePost(postId: _post.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted ✅')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  void _openComments() {
    showCommentsBottomSheet(
      context,
      postId: _post.id,
      autoFocusComposer: false,
      onCountChanged: (n) {
        setState(() {
          _post = PostModel(
            id: _post.id,
            type: _post.type,
            caption: _post.caption,
            context: _post.context,
            createdAt: _post.createdAt,
            author: _post.author,
            media: _post.media,
            likeCount: _post.likeCount,
            commentCount: n,
            isLikedByMe: _post.isLikedByMe,
            category: _post.category,
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final media = post.media;
    final images = media
        .where((m) => m.type.toUpperCase() == 'IMAGE')
        .map((m) => m.url)
        .toList();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black12,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: const BackButton(),
        titleSpacing: 0,
        title: PostDetailsHeader(
          post: post,
          onAuthorTap: () {
            final uid = post.author.id;
            if (uid <= 0) return;
            ProfileNavigation.openUserProfile(context, uid);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onPressed: () => PostActionSheet.show(
              context,
              post: _post,
              isOwn: _canEdit,
              onEdit: _canEdit ? _openEdit : null,
              onDelete: _canEdit ? _deletePost : null,
              onPostChanged: (updated) {
                if (mounted) setState(() => _post = updated);
              },
            ),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              final fundraisingId = _post.fundraisingCampaignId;
              if (fundraisingId != null) {
                ShareService.share(context,
                    type: 'fundraising', id: fundraisingId);
              } else {
                ShareService.share(context, type: 'post', id: _post.id);
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ── Post caption ──────────────────────────────────────────
                if ((post.caption ?? '').isNotEmpty)
                  _CaptionSection(
                    post: post,
                    isBackgroundTextPost: _isBackgroundTextPost(post),
                  ),

                // ── Media carousel ────────────────────────────────────────
                if (media.isNotEmpty)
                  PostMediaCarousel(
                    post: post,
                    media: media,
                    imageUrls: images,
                  ),

                // ── Separator before actions ──────────────────────────────
                const SizedBox(height: 6),

                // ── Stats + Action row ────────────────────────────────────
                PostDetailsActions(
                  post: post,
                  onChanged: (updated) => setState(() => _post = updated),
                  onOpenComments: _openComments,
                ),

                // ── Comments preview ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: CommentsPreviewSection(
                    postId: post.id,
                    previewCount: 20,
                    totalCount: post.commentCount,
                    reloadToken: _commentsReload,
                    onViewAll: _openComments,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Sticky comment composer (keyboard-safe) ───────────────────
          _CommentComposerBar(
            myAvatarUrl: _myAvatarUrl,
            postId: _post.id,
            onCountChanged: (n) {
              setState(() {
                _post = PostModel(
                  id: _post.id,
                  type: _post.type,
                  caption: _post.caption,
                  context: _post.context,
                  createdAt: _post.createdAt,
                  author: _post.author,
                  media: _post.media,
                  likeCount: _post.likeCount,
                  commentCount: n,
                  isLikedByMe: _post.isLikedByMe,
                  category: _post.category,
                );
              });
            },
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Caption section — handles styled short-text backgrounds and read-more
// ═════════════════════════════════════════════════════════════════════════════

class _CaptionSection extends StatelessWidget {
  final PostModel post;
  final bool isBackgroundTextPost;

  const _CaptionSection({
    required this.post,
    required this.isBackgroundTextPost,
  });

  @override
  Widget build(BuildContext context) {
    final styleId = post.backgroundStyle;
    if (isBackgroundTextPost) {
      final style = PostBackgroundStyle.find(styleId);
      return ShortPostBackgroundBox(
        caption: cleanPostBodyForDisplay(post.caption!),
        style: style,
        fullWidth: true,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: _ReadMoreText(
        text: cleanPostBodyForDisplay(post.caption!),
        trimLines: 8,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(height: 1.4),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Sticky comment composer bar — always visible at the bottom
// ═════════════════════════════════════════════════════════════════════════════

class _CommentComposerBar extends StatelessWidget {
  final String? myAvatarUrl;
  final int postId;
  final void Function(int newCount) onCountChanged;

  const _CommentComposerBar({
    required this.myAvatarUrl,
    required this.postId,
    required this.onCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFEFEFEF),
                backgroundImage:
                    (myAvatarUrl ?? '').isEmpty
                        ? null
                        : NetworkImage(myAvatarUrl!),
                child: (myAvatarUrl ?? '').isEmpty
                    ? const Icon(Icons.person, size: 18,
                        color: Colors.black45)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => showCommentsBottomSheet(
                    context,
                    postId: postId,
                    autoFocusComposer: true,
                    onCountChanged: onCountChanged,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Write a comment…',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () => showCommentsBottomSheet(
                  context,
                  postId: postId,
                  autoFocusComposer: true,
                  onCountChanged: onCountChanged,
                ),
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
                tooltip: 'Open comments',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Read-more helper for long post captions
// ═════════════════════════════════════════════════════════════════════════════

class _ReadMoreText extends StatefulWidget {
  final String text;
  final int trimLines;
  final TextStyle? style;

  const _ReadMoreText({
    required this.text,
    this.trimLines = 3,
    this.style,
  });

  @override
  State<_ReadMoreText> createState() => _ReadMoreTextState();
}

class _ReadMoreTextState extends State<_ReadMoreText> {
  bool _expanded = false;
  bool _overflow = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant _ReadMoreText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.trimLines != widget.trimLines) {
      _expanded = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  void _measure() {
    if (!mounted) return;
    final maxW = context.size?.width;
    if (maxW == null || maxW <= 0) return;

    final tp = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: widget.style ?? DefaultTextStyle.of(context).style,
      ),
      maxLines: widget.trimLines,
      textDirection: TextDirection.ltr,
      ellipsis: '…',
    )..layout(maxWidth: maxW);

    final didOverflow = tp.didExceedMaxLines;
    if (didOverflow != _overflow) {
      setState(() => _overflow = didOverflow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.style ?? DefaultTextStyle.of(context).style;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: textStyle,
          maxLines: _expanded ? null : widget.trimLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (_overflow)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _expanded ? 'Read less' : 'Read more',
                style: textStyle.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}
