import 'package:bpa_app/core/analytics/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/core/theme/typography.dart';
import 'package:bpa_app/core/widgets/fit_width_media.dart';
import 'package:bpa_app/app/router/app_routes.dart';
import 'package:bpa_app/core/storage/local_storage.dart';

import 'package:bpa_app/features/posts/data/datasources/posts_remote_ds.dart';

import 'package:bpa_app/features/posts/data/models/post_model.dart';
import 'package:bpa_app/features/posts/presentation/widgets/comments_preview_section.dart';
import 'package:bpa_app/features/posts/presentation/screens/reels_player_screen.dart';
import 'package:bpa_app/core/media/fullscreen_gallery_viewer.dart';
import 'package:bpa_app/features/posts/presentation/widgets/report_bottom_sheet.dart';
import 'package:bpa_app/features/posts/presentation/widgets/comments_bottom_sheet.dart';
import 'package:bpa_app/core/services/share_service.dart';

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

  final _commentCtrl = TextEditingController();
  bool _sendingComment = false;
  int _commentsReload = 0;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadMe();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sendingComment) return;

    setState(() => _sendingComment = true);
    try {
      final created = await _ds.addComment(_post.id, text);
      await AnalyticsService.instance.logCommentCreated(
        postId: _post.id,
        commentId: created.id,
      );
      if (!mounted) return;
      _commentCtrl.clear();
      setState(() {
        _commentsReload++;
        _post = PostModel(
          id: _post.id,
          type: _post.type,
          caption: _post.caption,
          context: _post.context,
          createdAt: _post.createdAt,
          author: _post.author,
          media: _post.media,
          likeCount: _post.likeCount,
          commentCount: _post.commentCount + 1,
          isLikedByMe: _post.isLikedByMe,
          category: _post.category,
          fundraisingCampaignId: _post.fundraisingCampaignId,
          fundraisingEmbed: _post.fundraisingEmbed,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment failed: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
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

  void _openReport() {
    ReportBottomSheet.showPost(context, postId: _post.id);
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
                category: _post.category, // Pass the existing category
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
      appBar: AppBar(
        leading: const BackButton(),
        titleSpacing: 0,
        title: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.visitorProfile,
              arguments: {'userId': post.author.id},
            );
          },
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
                      style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      _timeAgo(post.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.appText.labelMedium!.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'edit') _openEdit();
              if (v == 'delete') _deletePost();
              if (v == 'report') _openReport();
            },
            itemBuilder: (_) => [
              if (_canEdit)
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (_canEdit)
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              const PopupMenuItem(value: 'report', child: Text('Report')),
            ],
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              final fundraisingId = _post.fundraisingCampaignId;
              if (fundraisingId != null) {
                ShareService.share(context, type: 'fundraising', id: fundraisingId);
              } else {
                ShareService.share(context, type: 'post', id: _post.id);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 86),
        children: [
          if ((post.caption ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: _ReadMoreText(
                text: post.caption!,
                trimLines: 8,
                style: context.appText.bodyLarge!.copyWith(height: 1.35),
              ),
            ),
          if (media.isNotEmpty)
            _MixedMediaCarousel(
              post: post,
              media: media,
              imageUrls: images,
            ),
          const SizedBox(height: 10),
          _ActionsRow(
            post: post,
            onChanged: (updated) => setState(() => _post = updated),
            onOpenComments: _openComments,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: CommentsPreviewSection(
              postId: post.id,
              previewCount: 20,
              totalCount: post.commentCount,
              reloadToken: _commentsReload,
              onViewAll: _openComments,
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
      // ✅ "Write comment" input now opens the bottom sheet.
      // This avoids the keyboard overlapping the input area.
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFEFEFEF),
                  backgroundImage: (_myAvatarUrl ?? '').isEmpty ? null : NetworkImage(_myAvatarUrl!),
                  child: (_myAvatarUrl ?? '').isEmpty
                      ? const Icon(Icons.person, size: 18, color: Colors.black45)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => showCommentsBottomSheet(
                      context,
                      postId: _post.id,
                      autoFocusComposer: true,
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
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Write a comment…',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => showCommentsBottomSheet(
                    context,
                    postId: _post.id,
                    autoFocusComposer: true,
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
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  tooltip: 'Open comments',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionsRow extends StatefulWidget {
  final PostModel post;
  final ValueChanged<PostModel> onChanged;
  final VoidCallback onOpenComments;

  const _ActionsRow({
    required this.post,
    required this.onChanged,
    required this.onOpenComments,
  });

  @override
  State<_ActionsRow> createState() => _ActionsRowState();
}

class _ActionsRowState extends State<_ActionsRow> {
  final _ds = PostsRemoteDs();
  bool _busy = false;

  Future<void> _toggleLike() async {
    if (_busy) return;
    setState(() => _busy = true);

    final p = widget.post;
    final currently = p.isLikedByMe;

    // optimistic update
    widget.onChanged(
      PostModel(
        id: p.id,
        type: p.type,
        caption: p.caption,
        context: p.context,
        createdAt: p.createdAt,
        author: p.author,
        media: p.media,
        likeCount: (p.likeCount + (currently ? -1 : 1)).clamp(0, 1 << 30),
        commentCount: p.commentCount,
        isLikedByMe: !currently,
        category: p.category,
        fundraisingCampaignId: p.fundraisingCampaignId,
        fundraisingEmbed: p.fundraisingEmbed,
      ),
    );

    try {
      final res = currently ? await _ds.unlikePost(p.id) : await _ds.likePost(p.id);
      final likeCount = (res['likeCount'] as num?)?.toInt();
      if (!mounted) return;
      if (likeCount != null) {
        final u = widget.post;
        widget.onChanged(
          PostModel(
            id: u.id,
            type: u.type,
            caption: u.caption,
            context: u.context,
            createdAt: u.createdAt,
            author: u.author,
            media: u.media,
            likeCount: likeCount,
            commentCount: u.commentCount,
            isLikedByMe: !currently,
            category: u.category,
            fundraisingCampaignId: u.fundraisingCampaignId,
            fundraisingEmbed: u.fundraisingEmbed,
          ),
        );
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${p.likeCount} Paws · ${p.commentCount} comments · 0 shares',
              style: context.appText.bodySmall!.copyWith(color: Colors.black54),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
          child: Row(
            children: [
              Expanded(
                child: _ReactionButton(
                  icon: p.isLikedByMe ? Icons.pets : Icons.pets_outlined,
                  label: 'Paw',
                  selected: p.isLikedByMe,
                  onTap: _toggleLike,
                ),
              ),
              Expanded(
                child: _ReactionButton(
                  icon: Icons.comment_outlined,
                  label: 'Comment',
                  onTap: widget.onOpenComments,
                ),
              ),
              Expanded(
                child: _ReactionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () {
                    final fundraisingId = p.fundraisingCampaignId;
                    if (fundraisingId != null) {
                      ShareService.share(context, type: 'fundraising', id: fundraisingId);
                    } else {
                      ShareService.share(context, type: 'post', id: p.id);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: selected ? context.colorScheme.primary : null),
            const SizedBox(width: 6),
            Text(
              label,
              style: context.appText.labelLarge!.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? context.colorScheme.primary : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MixedMediaCarousel extends StatefulWidget {
  final PostModel post;
  final List<PostMediaModel> media;
  final List<String> imageUrls;

  const _MixedMediaCarousel({
    required this.post,
    required this.media,
    required this.imageUrls,
  });

  @override
  State<_MixedMediaCarousel> createState() => _MixedMediaCarouselState();
}

class _MixedMediaCarouselState extends State<_MixedMediaCarousel> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _openImage(int imageIndex) {
    final tagPrefix = 'post-${widget.post.id}-carousel';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenGalleryViewer(
          urls: widget.imageUrls,
          initialIndex: imageIndex,
          heroTagPrefix: tagPrefix,
        ),
      ),
    );
  }

  void _openVideo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReelsPlayerScreen(reels: [widget.post], initialIndex: 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final count = media.length;
    final tagPrefix = 'post-${widget.post.id}-carousel';

    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.width * 9 / 16,
          child: PageView.builder(
            controller: _page,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: count,
            itemBuilder: (_, i) {
              final m = media[i];
              final t = m.type.toUpperCase();
              if (t == 'VIDEO') {
                return InkWell(
                  onTap: _openVideo,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.black12),
                      const Center(
                        child: Icon(Icons.play_circle_fill, size: 72, color: Colors.white),
                      ),
                    ],
                  ),
                );
              }

              // IMAGE fallback
              final imageIndex = widget.imageUrls.indexOf(m.url);
              return InkWell(
                onTap: () => _openImage(imageIndex < 0 ? 0 : imageIndex),
                child: Hero(
                  tag: '$tagPrefix-$i',
                  child: Image.network(
                    m.url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.black12,
                      child: const Center(child: Icon(Icons.broken_image_outlined)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (count > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                count,
                (i) => Container(
                  width: i == _index ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _index ? Colors.black87 : Colors.black26,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ImagesGrid extends StatelessWidget {
  final List<String> urls;
  final int postId;

  const _ImagesGrid({required this.urls, required this.postId});

  @override
  Widget build(BuildContext context) {
    if (urls.length == 1) {
      final tagPrefix = 'post-$postId-img';
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullscreenGalleryViewer(
                urls: urls,
                initialIndex: 0,
                heroTagPrefix: tagPrefix,
              ),
            ),
          );
        },
        child: Hero(
          tag: '$tagPrefix-0',
          child: FitWidthNetworkImage(url: urls.first),
        ),
      );
    }

    final tagPrefix = 'post-$postId-img';
    final count = urls.length.clamp(2, 4);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemBuilder: (_, i) {
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullscreenGalleryViewer(
                  urls: urls,
                  initialIndex: i,
                  heroTagPrefix: tagPrefix,
                ),
              ),
            );
          },
          child: Hero(
            tag: '$tagPrefix-$i',
            child: Image.network(urls[i], fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

// Simple, dependency-free read more / read less.
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
    if (oldWidget.text != widget.text || oldWidget.trimLines != widget.trimLines) {
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
