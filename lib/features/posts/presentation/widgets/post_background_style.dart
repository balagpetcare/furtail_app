import 'dart:math' as math;

import 'package:flutter/material.dart';

// ── Pattern painters ──────────────────────────────────────────────────────

/// Subtle print pattern — small semi-transparent shapes scattered
/// across the background. Rendered via CustomPainter so no asset files needed.
class PrintPatternPainter extends CustomPainter {
  final Color color;
  PrintPatternPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final rng = math.Random(42); // fixed seed = deterministic pattern
    final patternCount = (size.width * size.height / 18000).round().clamp(6, 24);

    for (int i = 0; i < patternCount; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final scale = 8 + rng.nextDouble() * 16;

      // Main pad
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: scale * 1.2, height: scale * 1.1),
        paint,
      );

      // Four toe pads
      for (int t = 0; t < 4; t++) {
        final angle = t * math.pi / 2 + rng.nextDouble() * 0.3;
        final dist = scale * 0.6;
        final tx = cx + math.cos(angle) * dist;
        final ty = cy + math.sin(angle) * dist;
        canvas.drawCircle(Offset(tx, ty), scale * 0.25, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Light confetti/playful pattern — small colorful circles scattered softly.
class ConfettiPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(123); // fixed seed
    final dotCount = (size.width * size.height / 8000).round().clamp(10, 40);

    for (int i = 0; i < dotCount; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final radius = 3 + rng.nextDouble() * 10;
      final opacity = 0.04 + rng.nextDouble() * 0.06;
      final hue = rng.nextDouble() * 360;

      final paint = Paint()
        ..color = HSLColor.fromAHSL(opacity, hue, 0.6, 0.7).toColor()
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Style model ──────────────────────────────────────────────────────────

enum BackgroundStyleType { solid, gradient, pattern }

class PostBackgroundStyle {
  final String id;
  final String name;
  final BackgroundStyleType type;
  final Gradient? gradient;
  final Color? color;
  final Color textColor;
  final CustomPainter Function()? patternBuilder;
  final String? patternId;

  const PostBackgroundStyle({
    required this.id,
    required this.name,
    required this.type,
    this.gradient,
    this.color,
    required this.textColor,
    this.patternBuilder,
    this.patternId,
  });

  static const List<PostBackgroundStyle> presets = [
    // 1. Normal (white / default)
    PostBackgroundStyle(
      id: 'none',
      name: 'Normal',
      type: BackgroundStyleType.solid,
      color: Color(0xFFFFFFFF),
      textColor: Colors.black87,
    ),
    // 2. Sunset Orange gradient
    PostBackgroundStyle(
      id: 'orange_red',
      name: 'Sunset Orange',
      type: BackgroundStyleType.gradient,
      gradient: LinearGradient(
        colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // 3. Neon Blue gradient
    PostBackgroundStyle(
      id: 'blue_purple',
      name: 'Neon Blue',
      type: BackgroundStyleType.gradient,
      gradient: LinearGradient(
        colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // 4. Deep Purple gradient
    PostBackgroundStyle(
      id: 'dark_purple',
      name: 'Deep Purple',
      type: BackgroundStyleType.gradient,
      gradient: LinearGradient(
        colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF56040)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // 5. Ocean Breeze gradient
    PostBackgroundStyle(
      id: 'green_teal',
      name: 'Ocean Breeze',
      type: BackgroundStyleType.gradient,
      gradient: LinearGradient(
        colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // 6. Midnight Dark gradient
    PostBackgroundStyle(
      id: 'midnight',
      name: 'Midnight',
      type: BackgroundStyleType.gradient,
      gradient: LinearGradient(
        colors: [Color(0xFF232526), Color(0xFF414345)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // 7. Print Pattern (CustomPainter)
    PostBackgroundStyle(
      id: 'print_pattern',
      name: 'Prints',
      type: BackgroundStyleType.pattern,
      color: Color(0xFFFCE4EC),
      textColor: Colors.black87,
      patternBuilder: _printBuilder,
      patternId: 'print',
    ),
    // 8. Confetti Pattern (CustomPainter)
    PostBackgroundStyle(
      id: 'confetti',
      name: 'Confetti',
      type: BackgroundStyleType.pattern,
      color: Color(0xFFE8F5E9),
      textColor: Colors.black87,
      patternBuilder: _confettiBuilder,
      patternId: 'confetti',
    ),
  ];

  static CustomPainter _printBuilder() => PrintPatternPainter();
  static CustomPainter _confettiBuilder() => ConfettiPatternPainter();

  static PostBackgroundStyle find(String? id) {
    if (id == null) return presets[0];
    return presets.firstWhere((p) => p.id == id, orElse: () => presets[0]);
  }
}

// ── Feed rendering widget ────────────────────────────────────────────────

class ShortPostBackgroundBox extends StatelessWidget {
  final String caption;
  final PostBackgroundStyle style;
  final VoidCallback? onTap;
  final double fontSize;
  /// When true, removes border-radius and shadow so the box renders
  /// edge-to-edge (used in the single-post detail screen).
  final bool fullWidth;

  const ShortPostBackgroundBox({
    super.key,
    required this.caption,
    required this.style,
    this.onTap,
    this.fontSize = 20,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          minHeight: fullWidth ? 220 : 180,
          maxHeight: fullWidth ? double.infinity : 420,
        ),
        decoration: BoxDecoration(
          color: style.color,
          gradient: style.gradient,
          borderRadius: fullWidth ? BorderRadius.zero : BorderRadius.circular(16),
          boxShadow: fullWidth
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Stack(
          children: [
            // Pattern covers the full background box area
            if (style.type == BackgroundStyleType.pattern && style.patternBuilder != null)
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: style.patternBuilder!(),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            // Text centered with its own padding
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: fullWidth ? 32 : 24,
                ),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: style.textColor,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Display-only body text cleaner ───────────────────────────────────────────

/// Strips metadata suffixes the backend appends to post captions.
/// Call before rendering body text; never mutate stored/API data.
///
/// Handles forms like:
///   " — activity Blessed"   (em dash)
///   " - feeling Happy"      (hyphen)
///   " | location Dhaka"     (pipe)
String cleanPostBodyForDisplay(String text) {
  return text
      .replaceAll(
        RegExp(
          r'\s*[—\-|]\s*(?:activity|feeling|location)\s+.+$',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
}

// ── Composer preview widget (used in the background picker circles) ───────

class BackgroundStylePreviewCircle extends StatelessWidget {
  final PostBackgroundStyle style;
  final bool isSelected;
  final double size;

  const BackgroundStylePreviewCircle({
    super.key,
    required this.style,
    required this.isSelected,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.type != BackgroundStyleType.gradient ? style.color : null,
        gradient: style.gradient,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
          width: isSelected ? 3 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Stack(
          children: [
            if (style.type == BackgroundStyleType.pattern && style.patternBuilder != null)
              CustomPaint(
                painter: style.patternBuilder!(),
                size: Size(size, size),
              ),
            if (isSelected)
              Center(
                child: Icon(Icons.check, color: style.textColor, size: size * 0.45),
              ),
          ],
        ),
      ),
    );
  }
}
