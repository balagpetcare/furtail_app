import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:furtail_app/core/media/furtail_cache_manager.dart';
import 'package:furtail_app/core/navigation/profile_navigation.dart';
import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/core/storage/local_storage.dart';
import 'package:furtail_app/features/posts/presentation/screens/post_details_screen.dart';
import 'package:furtail_app/features/posts/presentation/widgets/comments_bottom_sheet.dart';
import 'package:furtail_app/features/posts/presentation/widgets/post_action_sheet.dart';

/// Premium dark immersive media viewer with post context.
///
/// Layout (bottom to top):
///   ┌─ close · position · more menu ────────────────────── top bar ─┐
///   │                                                               │
///   │               ┌─ InteractiveViewer ──┐                        │
///   │               │  CachedNetworkImage   │                        │
///   │               └───────────────────────┘                       │
///   │                                                               │
///   ├─ avatar · name · time ─────────────── author bar ─────────────┤
///   ├─ caption preview (expandable) ────────────────────────────────┤
///   ├─ counts ──────────────────────────────────────────────────────┤
///   ├─ [Paw] [Comment] [Share] ──────────── actions ───────────────┤
///   └───────────────────────────────────────────────────────────────┘
class MediaViewerScreen extends StatefulWidget {
  final PostModel post;
  final int initialIndex;

  const MediaViewerScreen({
    super.key,
    required this.post,
    this.initialIndex = 0,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  final _ds = PostsRemoteDs();
  late PostModel _post;
  late PageController _page;
  int _index = 0;
  bool _uiVisible = true;
  bool _captionExpanded = false;
  int? _meId;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _index = widget.initialIndex.clamp(0, _imageUrls.length - 1);
    _page = PageController(initialPage: _index);
    LocalStorage.getUserId().then((id) {
      if (mounted) setState(() => _meId = id);
    });
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  List<String> get _imageUrls =>
      _post.media
          .where((m) => m.type.toUpperCase() == 'IMAGE')
          .map((m) => m.url)
          .toList();

  bool get _isSingle => _imageUrls.length <= 1;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── Like ────────────────────────────────────────────────────────────

  Future<void> _toggleLike() async {
    final currently = _post.isLikedByMe;
    setState(() {
      _post = _post.copyWith(
        likeCount: (_post.likeCount + (currently ? -1 : 1)).clamp(0, 1 << 30),
        isLikedByMe: !currently,
      );
    });
    try {
      final res =
          currently ? await _ds.unlikePost(_post.id) : await _ds.likePost(_post.id);
      final likeCount = (res['likeCount'] as num?)?.toInt();
      if (likeCount != null && mounted) {
        setState(() {
          _post = _post.copyWith(likeCount: likeCount, isLikedByMe: !currently);
        });
      }
    } catch (_) {
      // Optimistic update stays; no rollback since server state is unknown.
    }
  }

  // ── Comments ────────────────────────────────────────────────────────

  void _openComments() {
    showCommentsBottomSheet(
      context,
      postId: _post.id,
      autoFocusComposer: false,
      onCountChanged: (n) {
        setState(() {
          _post = _post.copyWith(commentCount: n);
        });
      },
    );
  }

  // ── Share ───────────────────────────────────────────────────────────

  void _sharePost() {
    final fundraisingId = _post.fundraisingCampaignId;
    if (fundraisingId != null) {
      ShareService.share(context, type: 'fundraising', id: fundraisingId);
    } else {
      ShareService.share(context, type: 'post', id: _post.id);
    }
  }

  // ── More menu ───────────────────────────────────────────────────────

  void _showMoreMenu() {
    final isOwn = _meId != null && _post.author.id == _meId;
    PostActionSheet.show(
      context,
      post: _post,
      isOwn: isOwn,
      onViewFullPost: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailsScreen(post: _post)),
      ),
      onPostChanged: (updated) {
        if (mounted) setState(() => _post = updated);
      },
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final urls = _imageUrls;
    if (urls.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined,
                  color: Colors.white38, size: 64),
              const SizedBox(height: 12),
              Text('No images available',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.white54)),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _uiVisible = !_uiVisible),
        child: Stack(
          children: [
            // ── Image PageView ──────────────────────────────────────
            PageView.builder(
              controller: _page,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final url = urls[i];
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      cacheManager: FurtailImageCacheManager(),
                      fit: BoxFit.contain,
                      placeholder: (_, _) => const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white38,
                        ),
                      ),
                      errorWidget: (_, _, _) => const Icon(
                        Icons.broken_image,
                        color: Colors.white38,
                        size: 64,
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── UI Overlay (toggle on tap) ──────────────────────────
            if (_uiVisible) ...[
              // Gradient at top for legibility
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Top bar
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                      ),
                      if (!_isSingle)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${_index + 1}/${urls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const Spacer(),
                      IconButton(
                        onPressed: _showMoreMenu,
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── Bottom overlay (semi-transparent) ───────────────────
            if (_uiVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 24,
                    bottom: MediaQuery.of(context).padding.bottom + 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Author bar ────────────────────────────────
                      InkWell(
                        onTap: () {
                          final uid = _post.author.id;
                          if (uid <= 0) return;
                          ProfileNavigation.openUserProfile(context, uid);
                        },
                        borderRadius: BorderRadius.circular(99),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.white12,
                                backgroundImage:
                                    (_post.author.avatarUrl ?? '').isNotEmpty
                                        ? NetworkImage(
                                            _post.author.avatarUrl!)
                                        : null,
                                child:
                                    (_post.author.avatarUrl ?? '').isEmpty
                                        ? const Icon(Icons.person,
                                            color: Colors.white60, size: 18)
                                        : null,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  _post.author.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _timeAgo(_post.createdAt),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                              if (_post.privacy != 'PUBLIC') ...[
                                const SizedBox(width: 6),
                                Icon(
                                  _post.privacy == 'PRIVATE'
                                      ? Icons.lock_outline
                                      : Icons.people_outline,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // ── Caption preview ──────────────────────────
                      if ((_post.caption ?? '').isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _post.caption!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                height: 1.35,
                              ),
                              maxLines: _captionExpanded ? null : 2,
                              overflow: _captionExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                            ),
                            if (_post.caption!.length > 120)
                              InkWell(
                                onTap: () => setState(() =>
                                    _captionExpanded = !_captionExpanded),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    _captionExpanded ? 'less' : 'more',
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.6),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                          ],
                        ),

                      // ── Stats row ─────────────────────────────────
                      Text(
                        '${_post.likeCount} Paws · '
                        '${_post.commentCount} comments · '
                        '${_post.shareCount} shares',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // ── Action buttons ────────────────────────────
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            _MediaActionButton(
                              icon: _post.isLikedByMe
                                  ? Icons.pets
                                  : Icons.pets_outlined,
                              label: 'Paw',
                              color: _post.isLikedByMe
                                  ? theme.colorScheme.primary
                                  : Colors.white70,
                              onTap: _toggleLike,
                            ),
                            _MediaActionButton(
                              icon: Icons.comment_outlined,
                              label: 'Comment',
                              color: Colors.white70,
                              onTap: _openComments,
                            ),
                            _MediaActionButton(
                              icon: Icons.share_outlined,
                              label: 'Share',
                              color: Colors.white70,
                              onTap: _sharePost,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Individual action button for the media viewer bottom bar.
class _MediaActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MediaActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
