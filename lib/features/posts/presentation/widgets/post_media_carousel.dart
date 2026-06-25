import 'package:flutter/material.dart';

import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/presentation/screens/media_viewer_screen.dart';
import 'package:furtail_app/features/posts/presentation/screens/reels_player_screen.dart';

/// Mixed media carousel for the post details screen.
///
/// Supports both IMAGE and VIDEO items in a single PageView.
/// Tapping an image opens [FullscreenGalleryViewer]; tapping a video
/// opens [ReelsPlayerScreen].
class PostMediaCarousel extends StatefulWidget {
  final PostModel post;
  final List<PostMediaModel> media;
  final List<String> imageUrls;

  const PostMediaCarousel({
    super.key,
    required this.post,
    required this.media,
    required this.imageUrls,
  });

  @override
  State<PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<PostMediaCarousel> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _openImage(int imageIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          post: widget.post,
          initialIndex: imageIndex,
        ),
      ),
    );
  }

  void _openVideo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ReelsPlayerScreen(reels: [widget.post], initialIndex: 0),
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
                      if ((m.thumbnailUrl ?? '').isNotEmpty)
                        Image.network(
                          m.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Container(color: Colors.black26),
                        )
                      else
                        Container(color: Colors.black26),
                      Container(
                          color: Colors.black.withValues(alpha: 0.20)),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 72,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                                blurRadius: 12, color: Colors.black45)
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // IMAGE fallback
              final imageIndex = widget.imageUrls.indexOf(m.url);
              return InkWell(
                onTap: () =>
                    _openImage(imageIndex < 0 ? 0 : imageIndex),
                child: Hero(
                  tag: '$tagPrefix-$i',
                  child: Image.network(
                    m.url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, _, _) => Container(
                      color: Colors.black12,
                      child: const Center(
                          child:
                              Icon(Icons.broken_image_outlined)),
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
                    color: i == _index
                        ? Colors.black87
                        : Colors.black26,
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
