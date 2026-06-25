import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:furtail_app/core/media/feed_video_player.dart';
import 'package:furtail_app/core/media/furtail_cache_manager.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';

class PostMediaGrid extends StatelessWidget {
  final List<PostMediaModel> media;
  final Function(int) onTap;

  const PostMediaGrid({
    super.key,
    required this.media,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: _buildLayout(context),
    );
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
            url: item.url,
            visibilityKey: 'post-grid-video-${item.id}',
            startMuted: true,
            enableAutoplay: true,
            aspectRatio: ratio,
            fit: BoxFit.cover,
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
          child: CachedNetworkImage(
            imageUrl: item.url,
            cacheManager: FurtailImageCacheManager(),
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              color: Colors.grey[200],
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (_, _, _) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
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

    return CachedNetworkImage(
      imageUrl: item.url,
      cacheManager: FurtailImageCacheManager(),
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        color: Colors.grey[200],
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, _, _) => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }
}
