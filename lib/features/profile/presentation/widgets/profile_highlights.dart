import 'package:flutter/material.dart';

/// Extra feature: quick highlights (Pinned posts, Featured photos, Insights).
class ProfileHighlights extends StatelessWidget {
  final VoidCallback onTapPinned;
  final VoidCallback onTapFeaturedPhotos;
  final VoidCallback onTapInsights;

  const ProfileHighlights({
    super.key,
    required this.onTapPinned,
    required this.onTapFeaturedPhotos,
    required this.onTapInsights,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE6E6E6)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Highlights',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _tile(
                  icon: Icons.push_pin_outlined,
                  title: 'Pinned Posts',
                  subtitle: 'Show your best',
                  onTap: onTapPinned,
                ),
                const SizedBox(width: 12),
                _tile(
                  icon: Icons.collections_outlined,
                  title: 'Featured Photos',
                  subtitle: 'Top moments',
                  onTap: onTapFeaturedPhotos,
                ),
                const SizedBox(width: 12),
                _tile(
                  icon: Icons.insights_outlined,
                  title: 'Insights',
                  subtitle: 'Views & visits',
                  onTap: onTapInsights,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFFF6F8FC),
          border: Border.all(color: const Color(0x11000000)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
