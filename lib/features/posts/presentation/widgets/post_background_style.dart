import 'package:flutter/material.dart';

class PostBackgroundStyle {
  final String id;
  final String name;
  final Gradient? gradient;
  final Color? color;
  final Color textColor;

  const PostBackgroundStyle({
    required this.id,
    required this.name,
    this.gradient,
    this.color,
    required this.textColor,
  });

  static const List<PostBackgroundStyle> presets = [
    PostBackgroundStyle(
      id: 'none',
      name: 'Normal',
      color: Color(0xFFF0F2F5),
      textColor: Colors.black87,
    ),
    PostBackgroundStyle(
      id: 'orange_red',
      name: 'Sunset Orange',
      gradient: LinearGradient(
        colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    PostBackgroundStyle(
      id: 'blue_purple',
      name: 'Neon Blue',
      gradient: LinearGradient(
        colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    PostBackgroundStyle(
      id: 'dark_purple',
      name: 'Deep Purple',
      gradient: LinearGradient(
        colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF56040)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    PostBackgroundStyle(
      id: 'green_teal',
      name: 'Ocean Breeze',
      gradient: LinearGradient(
        colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
  ];

  static PostBackgroundStyle find(String? id) {
    if (id == null) return presets[0];
    return presets.firstWhere((p) => p.id == id, orElse: () => presets[0]);
  }
}

class ShortPostBackgroundBox extends StatelessWidget {
  final String caption;
  final PostBackgroundStyle style;
  final VoidCallback? onTap;

  const ShortPostBackgroundBox({
    super.key,
    required this.caption,
    required this.style,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 180),
        decoration: BoxDecoration(
          color: style.color,
          gradient: style.gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        alignment: Alignment.center,
        child: Text(
          caption,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: style.textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
