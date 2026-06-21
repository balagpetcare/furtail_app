import 'package:flutter/material.dart';

import 'package:bpa_app/core/theme/typography.dart';
class ProfileGallery extends StatelessWidget {
  final List<String> urls;

  const ProfileGallery({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Gallery",
          style: context.appText.bodyLarge!.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: urls.length.clamp(0, 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, i) {
            final url = urls[i];
            return GestureDetector(
              onTap: () => _openViewer(context, urls, i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.white.withOpacity(0.06),
                    child: Icon(
                      Icons.image,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _openViewer(BuildContext context, List<String> urls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GalleryViewer(urls: urls, initialIndex: initialIndex),
      ),
    );
  }
}

class _GalleryViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _GalleryViewer({required this.urls, required this.initialIndex});

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _c;

  @override
  void initState() {
    super.initState();
    _c = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: PageView.builder(
        controller: _c,
        itemCount: widget.urls.length,
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Image.network(widget.urls[i], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
