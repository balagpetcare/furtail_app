import 'package:flutter/material.dart';

/// Highlights card — shown on the owner profile.
/// Feature is not yet implemented; shows a polished empty/coming-soon state.
class ProfileHighlights extends StatelessWidget {
  // Callbacks kept for API compatibility; they are not used until feature ships.
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8EAED)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_awesome_outlined, color: cs.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Highlights',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  'Pin posts, feature photos & view insights — coming soon.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.lock_clock_outlined, size: 18, color: Colors.black26),
        ],
      ),
    );
  }
}
