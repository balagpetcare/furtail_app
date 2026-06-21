import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Full-width image renderer.
///
/// Requirement:
/// - width: 100% of screen
/// - height: flexible (keeps original aspect ratio)
/// - uses BoxFit.fitWidth
class FitWidthNetworkImage extends StatelessWidget {
  final String url;
  final BorderRadius? borderRadius;

  const FitWidthNetworkImage({
    super.key,
    required this.url,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final child = CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (context, provider) {
        return Image(
          image: provider,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
        );
      },
      placeholder: (_, __) => Container(
        width: double.infinity,
        color: Colors.black12,
        child: const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        width: double.infinity,
        color: Colors.black12,
        child: const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    );

    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}

class FitWidthFileImage extends StatelessWidget {
  final File file;
  final BorderRadius? borderRadius;

  const FitWidthFileImage({super.key, required this.file, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final child = Image.file(
      file,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      alignment: Alignment.topCenter,
    );
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}
