import 'package:flutter/material.dart';

import 'package:bpa_app/core/theme/spacing.dart';
import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/core/theme/typography.dart';
import 'package:bpa_app/core/widgets/bpa_network_image.dart';

class StorySection extends StatelessWidget {
  const StorySection({super.key});

  static const _stories = [
    _StoryData('Your Story', isMyStory: true, imgUrl: null),
    _StoryData('Mimi & Mom', imgUrl: 'https://i.pravatar.cc/150?img=9'),
    _StoryData('Dr. Karim', imgUrl: 'https://i.pravatar.cc/150?img=11'),
    _StoryData('Rescue Paws', imgUrl: 'https://i.pravatar.cc/150?img=12'),
    _StoryData('Adoption', imgUrl: 'https://i.pravatar.cc/150?img=3'),
    _StoryData('Training', imgUrl: 'https://i.pravatar.cc/150?img=7'),
    _StoryData('Vet Care', imgUrl: 'https://i.pravatar.cc/150?img=6'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        itemCount: _stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) =>
            _StoryItem(data: _stories[index]),
      ),
    );
  }
}

class _StoryData {
  final String name;
  final String? imgUrl;
  final bool isMyStory;

  const _StoryData(this.name, {this.imgUrl, this.isMyStory = false});
}

class _StoryItem extends StatelessWidget {
  final _StoryData data;

  const _StoryItem({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    const avatarSize = 56.0;
    const labelWidth = 72.0;

    return SizedBox(
      width: labelWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.primary, width: 2),
                ),
                child: BpaNetworkAvatar(
                  imageUrl: data.isMyStory
                      ? 'https://i.pravatar.cc/150?img=5'
                      : data.imgUrl,
                  displayName: data.name,
                  radius: avatarSize / 2 - 2,
                  backgroundColor: cs.surfaceContainerHighest,
                  foregroundColor: cs.primary,
                ),
              ),
              if (data.isMyStory)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 2),
                    ),
                    child: Icon(
                      Icons.add,
                      color: cs.onPrimary,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            data.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.appText.labelMedium!.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
