import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:bpa_app/core/media/fullscreen_gallery_viewer.dart';
import 'package:bpa_app/core/media/fullscreen_video_player_screen.dart';
import 'package:bpa_app/features/fundraising/data/models/fundraising_models.dart';

class FundraisingMediaCarousel extends StatefulWidget {
  final List<FundraisingMediaItem> media;
  const FundraisingMediaCarousel({super.key, required this.media});

  @override
  State<FundraisingMediaCarousel> createState() =>
      _FundraisingMediaCarouselState();
}

class _FundraisingMediaCarouselState extends State<FundraisingMediaCarousel> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.media.length;
    final imageUrls = widget.media
        .where((m) => !(m.type.toUpperCase().contains('VIDEO')))
        .map((m) => m.url)
        .toList();

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: total,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (ctx, i) {
                  final m = widget.media[i];
                  final isVideo = m.type.toUpperCase().contains('VIDEO');
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InkWell(
                      onTap: () {
                        if (isVideo) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  FullscreenVideoPlayerScreen(url: m.url),
                            ),
                          );
                        } else {
                          final imageIndex = imageUrls.indexOf(m.url);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FullscreenGalleryViewer(
                                urls: imageUrls, // ✅ ঠিক parameter
                                initialIndex: imageIndex < 0 ? 0 : imageIndex,
                              ),
                            ),
                          );
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (isVideo)
                              _VideoCover(url: m.url)
                            else
                              CachedNetworkImage(
                                imageUrl: m.url,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: const Color(0xFFF2F2F2),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: const Color(0xFFF2F2F2),
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                  ),
                                ),
                              ),
                            if (isVideo)
                              const Align(
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.play_circle_fill,
                                  size: 56,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (total > 1)
                Positioned(
                  right: 26,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_index + 1}/$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (total > 1) const SizedBox(height: 10),
        if (total > 1)
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: total,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final m = widget.media[i];
                final isVideo = m.type.toUpperCase().contains('VIDEO');
                final isActive = i == _index;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut,
                    );
                  },
                  child: Container(
                    width: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? Colors.black
                            : const Color(0xFFE7E7E7),
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (isVideo)
                            Container(color: const Color(0xFF111111))
                          else
                            CachedNetworkImage(
                              imageUrl: m.url,
                              fit: BoxFit.cover,
                            ),
                          if (isVideo)
                            const Center(
                              child: Icon(
                                Icons.play_circle_filled,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _VideoCover extends StatelessWidget {
  final String url;
  const _VideoCover({required this.url});

  @override
  Widget build(BuildContext context) {
    // For now, show a dark cover. (Feed video player is heavier; avoid in details carousel)
    return Container(color: const Color(0xFF111111));
  }
}
