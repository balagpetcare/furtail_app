import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'furtail_cache_manager.dart';

/// Facebook-like fullscreen image viewer.
///
/// Features:
/// - Swipe left/right across images
/// - Pinch/zoom via InteractiveViewer
/// - Optional hero animation (set [heroTagPrefix])
class FullscreenGalleryViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  final String? heroTagPrefix;

  const FullscreenGalleryViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    this.heroTagPrefix,
  });

  @override
  State<FullscreenGalleryViewer> createState() => _FullscreenGalleryViewerState();
}

class _FullscreenGalleryViewerState extends State<FullscreenGalleryViewer> {
  late final PageController _page;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, (widget.urls.length - 1).clamp(0, 999));
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    if (urls.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text('No image', style: TextStyle(color: Colors.white))));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final url = urls[i];
              final heroTag = widget.heroTagPrefix == null ? null : '${widget.heroTagPrefix}-$i';
              final img = InteractiveViewer(
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (_, _, _) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  ),
                ),
              );

              if (heroTag == null) return img;
              return Hero(tag: heroTag, child: img);
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    '${_index + 1}/${urls.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
