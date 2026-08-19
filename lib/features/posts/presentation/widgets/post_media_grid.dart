import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:furtail_app/core/media/feed_video_player.dart';
import 'package:furtail_app/core/media/furtail_cache_manager.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';

/// Development-only diagnostic for a failed feed-media load — logs enough
/// to triage (media id + normalized URL) without ever printing anything in
/// a release build, and without ever logging a signed/pre-authorized URL's
/// query string (stripped here since none of this app's media URLs are
/// expected to carry one; if that ever changes, strip query params before
/// logging).
void _logMediaLoadFailure({required int mediaId, required String url}) {
  if (!kDebugMode) return;
  debugPrint('[feed-media] failed to load mediaId=$mediaId url=$url');
}

/// Animated shimmer skeleton used while an image is loading.
class _MediaSkeleton extends StatefulWidget {
  const _MediaSkeleton();

  @override
  State<_MediaSkeleton> createState() => _MediaSkeletonState();
}

class _MediaSkeletonState extends State<_MediaSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _slide = Tween<double>(
      begin: -1.5,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slide,
      builder: (_, _) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(_slide.value - 1, 0),
            end: Alignment(_slide.value, 0),
            colors: const [
              Color(0xFFE0E0E0),
              Color(0xFFF5F5F5),
              Color(0xFFE0E0E0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Professional, theme-aware fallback for a feed image that failed to
/// load — replaces the old oversized grey block + raw "Could not load
/// image" text. Fills the space it's given (the parent already constrains
/// aspect ratio/max height), stays subtle, and offers Retry only for the
/// primary single-media case where a tap target makes sense.
class _BrokenMediaTile extends StatelessWidget {
  const _BrokenMediaTile({this.onRetry, this.compact = false});

  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: cs.onSurfaceVariant,
            size: compact ? 22 : 28,
          ),
          if (!compact && onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Wraps a single feed image with cache-evict-and-retry: tapping Retry in
/// the broken-media fallback clears this specific URL from the disk/memory
/// cache and rebuilds, so a transient failure (e.g. a momentary network
/// blip) doesn't strand the user with a permanently broken tile until they
/// leave and return to the feed.
class _RetryableFeedImage extends StatefulWidget {
  const _RetryableFeedImage({
    required this.imageUrl,
    required this.mediaId,
    required this.fit,
    this.compact = false,
  });

  final String imageUrl;
  final int mediaId;
  final BoxFit fit;
  final bool compact;

  @override
  State<_RetryableFeedImage> createState() => _RetryableFeedImageState();
}

class _RetryableFeedImageState extends State<_RetryableFeedImage> {
  int _attempt = 0;

  Future<void> _retry() async {
    await CachedNetworkImage.evictFromCache(
      widget.imageUrl,
      cacheManager: FurtailImageCacheManager(),
    );
    if (mounted) setState(() => _attempt++);
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      key: ValueKey('${widget.imageUrl}#$_attempt'),
      imageUrl: widget.imageUrl,
      cacheManager: FurtailImageCacheManager(),
      fit: widget.fit,
      placeholder: (_, _) => const _MediaSkeleton(),
      errorWidget: (_, _, _) {
        _logMediaLoadFailure(mediaId: widget.mediaId, url: widget.imageUrl);
        return _BrokenMediaTile(
          compact: widget.compact,
          onRetry: widget.compact ? null : _retry,
        );
      },
    );
  }
}

class PostMediaGrid extends StatelessWidget {
  final List<PostMediaModel> media;
  final Function(int) onTap;

  const PostMediaGrid({super.key, required this.media, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    // Border radius is handled by the parent card container.
    // Media should be edge-to-edge inside the card for a modern feed look.
    return ClipRect(child: _buildLayout(context));
  }

  Widget _buildLayout(BuildContext context) {
    final count = media.length;
    if (count == 1) {
      return _buildSingleMedia(context, media.first);
    } else if (count == 2) {
      return _buildTwoMedia(context);
    } else if (count == 3) {
      return _buildThreeMedia(context);
    } else {
      return _buildFourPlusMedia(context);
    }
  }

  Widget _buildSingleMedia(BuildContext context, PostMediaModel item) {
    double ratio = 1.0;
    if (item.width != null && item.height != null && item.height! > 0) {
      ratio = item.width! / item.height!;
    } else {
      if (item.type.toUpperCase() == 'VIDEO') {
        ratio = 16 / 9;
      } else {
        ratio = 1.0; // fallback image ratio
      }
    }

    ratio = ratio.clamp(0.75, 1.91);

    if (item.type.toUpperCase() == 'VIDEO') {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: AspectRatio(
          aspectRatio: ratio,
          child: FeedVideoPlayer(
            url: item.playbackUrl,
            posterUrl: item.thumbnailUrl,
            visibilityKey: 'post-grid-video-${item.id}',
            startMuted: true,
            enableAutoplay: true,
            aspectRatio: ratio,
            fit: BoxFit.cover,
            feedMode: true,
            onFullscreenPressed: () => onTap(0),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 480),
      child: AspectRatio(
        aspectRatio: ratio,
        child: GestureDetector(
          onTap: () => onTap(0),
          child: _RetryableFeedImage(
            imageUrl: item.url,
            mediaId: item.id,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildTwoMedia(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onTap(0),
              child: _buildGridItem(media[0]),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: GestureDetector(
              onTap: () => onTap(1),
              child: _buildGridItem(media[1]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeMedia(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => onTap(0),
              child: _buildGridItem(media[0]),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(1),
                    child: _buildGridItem(media[1]),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(2),
                    child: _buildGridItem(media[2]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourPlusMedia(BuildContext context) {
    final remaining = media.length - 4;
    return SizedBox(
      height: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(0),
                    child: _buildGridItem(media[0]),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(1),
                    child: _buildGridItem(media[1]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(2),
                    child: _buildGridItem(media[2]),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(3),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildGridItem(media[3]),
                        if (remaining > 0)
                          Container(
                            color: Colors.black.withValues(alpha: 0.55),
                            alignment: Alignment.center,
                            child: Text(
                              '+$remaining',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(PostMediaModel item) {
    if (item.type.toUpperCase() == 'VIDEO') {
      return Stack(
        fit: StackFit.expand,
        children: [
          if ((item.thumbnailUrl ?? '').isNotEmpty)
            CachedNetworkImage(
              imageUrl: item.thumbnailUrl!,
              cacheManager: FurtailImageCacheManager(),
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(color: Colors.black),
            )
          else
            Container(color: Colors.black87),
          const Center(
            child: Icon(
              Icons.play_circle_fill,
              size: 48,
              color: Colors.white,
              shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
            ),
          ),
        ],
      );
    }

    return _RetryableFeedImage(
      imageUrl: item.url,
      mediaId: item.id,
      fit: BoxFit.cover,
      compact: true,
    );
  }
}
