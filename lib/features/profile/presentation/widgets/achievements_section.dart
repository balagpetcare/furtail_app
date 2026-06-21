
import 'package:flutter/material.dart';

import 'package:bpa_app/core/theme/typography.dart';
class AchievementUiModel {
  final String name;
  final IconData icon;
  final int requiredPoints;
  final String description;
  final String howTo;

  const AchievementUiModel({
    required this.name,
    required this.icon,
    required this.requiredPoints,
    required this.description,
    required this.howTo,
  });
}

/// Achievements (My Awards) section.
/// - Colorful if achieved; grayscale if not.
/// - Tap shows details or 'How to achieve'.
/// - Progress bar based on total achieved.
class AchievementsSection extends StatelessWidget {
  final int points;

  const AchievementsSection({super.key, required this.points});

  List<AchievementUiModel> get _all => const [
        AchievementUiModel(
          name: 'First Post',
          icon: Icons.edit_square,
          requiredPoints: 20,
          description: 'Publish your first status update.',
          howTo: 'Create a post from your profile and share a short update.',
        ),
        AchievementUiModel(
          name: 'Photo Sharer',
          icon: Icons.photo_camera,
          requiredPoints: 120,
          description: 'Share photos and engage with the community.',
          howTo: 'Upload 5 photos in your posts and receive at least 10 likes.',
        ),
        AchievementUiModel(
          name: 'Friendly',
          icon: Icons.group,
          requiredPoints: 300,
          description: 'Build connections and follow friends.',
          howTo: 'Follow 20 people and interact with their posts consistently.',
        ),
        AchievementUiModel(
          name: 'Pet Parent',
          icon: Icons.pets,
          requiredPoints: 500,
          description: 'Add pets and keep their profiles updated.',
          howTo: 'Add at least 2 pets and complete their profiles with photos.',
        ),
        AchievementUiModel(
          name: 'Top Member',
          icon: Icons.emoji_events,
          requiredPoints: 1000,
          description: 'Reach a high point milestone.',
          howTo: 'Post regularly, earn reactions/comments, and stay active weekly.',
        ),
        AchievementUiModel(
          name: 'Community Helper',
          icon: Icons.volunteer_activism,
          requiredPoints: 2000,
          description: 'Help others with helpful posts and comments.',
          howTo: 'Share helpful tips and get 50 positive reactions from users.',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final achievedCount = _all.where((a) => points >= a.requiredPoints).length;
    final total = _all.length;
    final progress = total == 0 ? 0.0 : achievedCount / total;
    final remaining = total - achievedCount;

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
          Text(
            'My Awards / Achievements',
            style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _all.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final a = _all[i];
                final achieved = points >= a.requiredPoints;
                return _AchievementCard(
                  model: a,
                  achieved: achieved,
                  onTap: () => _showAchievementDialog(context, a, achieved),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress, minHeight: 10),
          ),
          const SizedBox(height: 8),
          Text(
            'Progress: ${(progress * 100).toStringAsFixed(0)}% • $remaining remaining',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            remaining == 0
                ? 'Tip: Amazing! Keep your streak going by posting and engaging.'
                : 'Tip: Post consistently, add pets, and interact to earn more points.',
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      ),
    );
  }

  void _showAchievementDialog(
    BuildContext context,
    AchievementUiModel a,
    bool achieved,
  ) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(achieved ? a.name : 'How to achieve: ${a.name}'),
          content: Text(
            achieved
                ? '${a.description}\n\nRequired points: ${a.requiredPoints}\nYour points: $points'
                : '${a.howTo}\n\nRequired points: ${a.requiredPoints}\nYour points: $points',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        );
      },
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementUiModel model;
  final bool achieved;
  final VoidCallback onTap;

  const _AchievementCard({required this.model, required this.achieved, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: 98,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        color: Colors.white,
        boxShadow: achieved
            ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 6))]
            : null,
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: achieved ? const Color(0xFFFFF5CC) : const Color(0xFFF2F2F2),
            ),
            child: Icon(model.icon, size: 22, color: achieved ? const Color(0xFFB8860B) : Colors.black45),
          ),
          const SizedBox(height: 10),
          Text(
            model.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.appText.labelMedium!.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: achieved
          ? child
          : ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: Stack(
                children: [
                  child,
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(Icons.lock_outline, size: 16, color: Colors.black.withOpacity(0.45)),
                  ),
                ],
              ),
            ),
    );
  }
}
