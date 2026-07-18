import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:furtail_app/core/media/feed_video_player.dart';
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
///   â”Œâ”€ close Â· position Â· more menu â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ top bar â”€â”
///   â”‚                                                               â”‚
///   â”‚               â”Œâ”€ InteractiveViewer â”€â”€â”                        â”‚
///   â”‚               â”‚  CachedNetworkImage   â”‚                        â”‚
///   â”‚               â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜                       â”‚
///   â”‚                                                               â”‚
///   â”œâ”€ avatar Â· name Â· time â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ author bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
///   â”œâ”€ caption preview (expandable) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
///   â”œâ”€ counts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
///   â”œâ”€ [Like] [Comment] [Share] â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
///   â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
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
  Timer? _statusPollTimer;
  bool _statusPollInFlight = false;
  bool _likeBusy = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _index = widget.initialIndex.clamp(0, _mediaList.length - 1);
    _page = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncProcessingPolling();
    });
    LocalStorage.getUserId().then((id) {
      if (mounted) setState(() => _meId = id);
    });
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _page.dispose();
    super.dispose();
  }

  bool _shouldPollMedia(PostMediaModel item) {
    return item.type.toUpperCase() == 'VIDEO' &&
        (item.status == 'PENDING' || item.status == 'PROCESSING') &&
        item.hlsUrl == null &&
        item.url.isNotEmpty;
  }

  void _syncProcessingPolling() {
    final item = _mediaList[_index];
    if (!_shouldPollMedia(item)) {
      _statusPollTimer?.cancel();
      _statusPollTimer = null;
      return;
    }

    if (_statusPollTimer != null) return;
    _statusPollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _statusPollInFlight) return;
      _statusPollInFlight = true;
      try {
        final fresh = await _ds.fetchPostById(_post.id);
        if (!mounted) return;

        final visibleMedia = fresh.media
            .where(
              (m) =>
                  m.type.toUpperCase() == 'IMAGE' ||
                  m.type.toUpperCase() == 'VIDEO',
            )
            .toList();
        if (_index >= visibleMedia.length) {
          setState(() => _post = fresh);
          _statusPollTimer?.cancel();
          _statusPollTimer = null;
          return;
        }

        final current = visibleMedia[_index];
        final hasPending = _shouldPollMedia(current);
        setState(() => _post = fresh);

        if (!hasPending) {
          _statusPollTimer?.cancel();
          _statusPollTimer = null;
        }
      } catch (_) {
        // Keep polling while the media is still processing; transient fetch failures are tolerated.
      } finally {
        _statusPollInFlight = false;
      }
    });
  }

  Widget _buildVideoStatusBadge(PostMediaModel item) {
    if (item.isFailed) {
      return Positioned(
        top: 12,
        left: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white, size: 14),
              SizedBox(width: 6),
              Text(
                'Processing failed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!item.showProcessingBadge) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 12,
      left: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white70,
              ),
            ),
            SizedBox(width: 6),
            Text(
              'Processing HD...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleViewer(BuildContext context, PostMediaModel item) {
    final theme = Theme.of(context);
    final isVideo = item.type.toUpperCase() == 'VIDEO';

    // Compute the video aspect ratio from metadata so we can size the player
    // area correctly before the controller initialises.
    double videoRatio = 16 / 9;
    if (isVideo && item.width != null && item.height != null && item.height! > 0) {
      videoRatio = item.width! / item.height!;
    }

    // Available body height (screen minus status bar minus app bar).
    final mq = MediaQuery.of(context);
    final bodyH = mq.size.height - mq.padding.top - kToolbarHeight;
    final bodyW = mq.size.width;

    // For the player area we derive a natural height from the aspect ratio and
    // then clamp it:
    //   â€¢ Portrait videos  (ratio < 1) â€” up to 70 % of the body so the video
    //     isn't tiny; narrower than full-width but noticeably larger than the
    //     old 55 % fixed split.
    //   â€¢ Landscape videos (ratio â‰¥ 1) â€” natural proportional height, capped
    //     at 55 % so the social section always has breathing room.
    // A minimum of 30 % is enforced so tiny/unusual videos still look decent.
    final double videoAreaH;
    if (isVideo) {
      final naturalH = bodyW / videoRatio;
      final maxH = videoRatio < 1.0 ? bodyH * 0.70 : bodyH * 0.55;
      videoAreaH = naturalH.clamp(bodyH * 0.30, maxH);
    } else {
      videoAreaH = bodyH * 0.55;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.40),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isVideo ? 'Video' : 'Media',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showMoreMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: videoAreaH,
            width: double.infinity,
            child: Container(
              color: Colors.black,
              child: _buildSingleMediaSurface(item),
            ),
          ),
          Container(height: 1, color: Colors.white10),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        final uid = _post.author.id;
                        if (uid <= 0) return;
                        ProfileNavigation.openUserProfile(context, uid);
                      },
                      borderRadius: BorderRadius.circular(99),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white12,
                              backgroundImage:
                                  (_post.author.avatarUrl ?? '').isNotEmpty
                                  ? NetworkImage(_post.author.avatarUrl!)
                                  : null,
                              child: (_post.author.avatarUrl ?? '').isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white60,
                                      size: 18,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _post.author.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _timeAgo(_post.createdAt),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if ((_post.caption ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _post.caption!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey.shade800, height: 1),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _MediaActionButton(
                          icon: _post.isLikedByMe
                              ? Icons.pets
                              : Icons.pets_outlined,
                          label: '${_likeLabel(context)} (${_post.likeCount})',
                          color: _post.isLikedByMe
                              ? theme.colorScheme.primary
                              : Colors.white70,
                          onTap: _toggleLike,
                        ),
                        _MediaActionButton(
                          icon: Icons.comment_outlined,
                          label: 'Comment (${_post.commentCount})',
                          color: Colors.white70,
                          onTap: _openComments,
                        ),
                        _MediaActionButton(
                          icon: Icons.share_outlined,
                          label: 'Share (${_post.shareCount})',
                          color: Colors.white70,
                          onTap: _sharePost,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleMediaSurface(PostMediaModel item) {
    if (item.type.toUpperCase() == 'VIDEO') {
      final ratio =
          (item.width != null && item.height != null && item.height! > 0)
          ? item.width! / item.height!
          : 16 / 9;

      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: FeedVideoPlayer(
              url: item.playbackUrl,
              visibilityKey: 'mv-video-${item.id}',
              startMuted: false,
              syncMuteWithGlobal: false,
              enableAutoplay: true,
              aspectRatio: ratio,
              fit: BoxFit.contain,
              isDetailViewer: true,
            ),
          ),
          _buildVideoStatusBadge(item),
        ],
      );
    }

    return Center(
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: CachedNetworkImage(
          imageUrl: item.url,
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
          errorWidget: (_, _, _) =>
              const Icon(Icons.broken_image, color: Colors.white38, size: 64),
        ),
      ),
    );
  }

  /// All displayable media (both IMAGE and VIDEO), in order.
  List<PostMediaModel> get _mediaList => _post.media
      .where(
        (m) =>
            m.type.toUpperCase() == 'IMAGE' || m.type.toUpperCase() == 'VIDEO',
      )
      .toList();

  bool get _isSingle => _mediaList.length <= 1;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // â”€â”€ Like â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String _likeLabel(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'bn'
        ? 'লাইক'
        : 'Like';
  }

  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    setState(() => _likeBusy = true);
    final currently = _post.isLikedByMe;
    setState(() {
      _post = _post.copyWith(
        likeCount: (_post.likeCount + (currently ? -1 : 1)).clamp(0, 1 << 30),
        isLikedByMe: !currently,
      );
    });
    try {
      final res = currently
          ? await _ds.unlikePost(_post.id)
          : await _ds.likePost(_post.id);
      final likeCount = (res['likeCount'] as num?)?.toInt();
      if (likeCount != null && mounted) {
        setState(() {
          _post = _post.copyWith(likeCount: likeCount, isLikedByMe: !currently);
        });
      }
    } catch (_) {
      // Optimistic update stays; no rollback since server state is unknown.
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  // â”€â”€ Comments â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  // â”€â”€ Share â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _sharePost() {
    final fundraisingId = _post.fundraisingCampaignId;
    if (fundraisingId != null) {
      ShareService.share(context, type: 'fundraising', id: fundraisingId);
    } else {
      ShareService.share(context, type: 'post', id: _post.id);
    }
  }

  // â”€â”€ More menu â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    final media = _mediaList;
    if (media.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_outlined,
                color: Colors.white38,
                size: 64,
              ),
              const SizedBox(height: 12),
              Text(
                'No media available',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white54),
              ),
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
    if (_isSingle) {
      return _buildSingleViewer(context, media.first);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _uiVisible = !_uiVisible),
        child: Stack(
          children: [
            // â”€â”€ Media PageView (images + videos) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            PageView.builder(
              controller: _page,
              itemCount: media.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                _syncProcessingPolling();
              },
              itemBuilder: (_, i) {
                final item = media[i];
                final isVideo = item.type.toUpperCase() == 'VIDEO';
                final isPending = item.showProcessingBadge;

                if (isVideo) {
                  // Full-width video player with aspect ratio
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      FeedVideoPlayer(
                        url: item.playbackUrl,
                        visibilityKey: 'mv-video-${item.id}',
                        startMuted: true,
                        enableAutoplay: true,
                        aspectRatio:
                            (item.width != null &&
                                item.height != null &&
                                item.height! > 0)
                            ? item.width! / item.height!
                            : 16 / 9,
                        fit: BoxFit.contain,
                      ),
                      if (item.isFailed)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Processing failed',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Processing HD badge for pending/processing videos
                      if (isPending)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Colors.white70,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Processing HDâ€¦',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                }

                // Image: use InteractiveViewer for zoom
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: item.url,
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

            // â”€â”€ UI Overlay (toggle on tap) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

              // Top bar â€” Facebook-style
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(
                    children: [
                      // Close button with visible circular bg
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (!_isSingle)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${_index + 1}/${media.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      // More menu with visible circular bg
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _showMoreMenu,
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // â”€â”€ Bottom overlay (semi-transparent) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                      // â”€â”€ Author bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                      InkWell(
                        onTap: () {
                          final uid = _post.author.id;
                          if (uid <= 0) return;
                          ProfileNavigation.openUserProfile(context, uid);
                        },
                        borderRadius: BorderRadius.circular(99),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.white12,
                                backgroundImage:
                                    (_post.author.avatarUrl ?? '').isNotEmpty
                                    ? NetworkImage(_post.author.avatarUrl!)
                                    : null,
                                child: (_post.author.avatarUrl ?? '').isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.white60,
                                        size: 18,
                                      )
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

                      // â”€â”€ Caption preview â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                                onTap: () => setState(
                                  () => _captionExpanded = !_captionExpanded,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    _captionExpanded ? 'less' : 'more',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                          ],
                        ),

                      // â”€â”€ Stats row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                      const SizedBox(height: 4),

                      // â”€â”€ Action buttons â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            _MediaActionButton(
                              icon: _post.isLikedByMe
                                  ? Icons.pets
                                  : Icons.pets_outlined,
                              label: '${_likeLabel(context)} (${_post.likeCount})',
                              color: _post.isLikedByMe
                                  ? theme.colorScheme.primary
                                  : Colors.white70,
                              onTap: _toggleLike,
                            ),
                            _MediaActionButton(
                              icon: Icons.comment_outlined,
                              label: 'Comment (${_post.commentCount})',
                              color: Colors.white70,
                              onTap: _openComments,
                            ),
                            _MediaActionButton(
                              icon: Icons.share_outlined,
                              label: 'Share (${_post.shareCount})',
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





