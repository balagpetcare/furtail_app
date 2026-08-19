import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';

/// Compact "what's on your mind?" entry point above the Stories strip —
/// tapping anywhere opens the existing canonical Create Post flow (this
/// widget never posts anything itself, it only navigates).
class HomeComposerEntry extends StatelessWidget {
  const HomeComposerEntry({
    super.key,
    required this.onTap,
    this.avatarUrl,
    this.userName = 'You',
  });

  final VoidCallback onTap;
  final String? avatarUrl;
  final String userName;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                FurtailNetworkAvatar(
                  imageUrl: avatarUrl,
                  displayName: userName,
                  radius: 18,
                  backgroundColor: cs.primaryContainer,
                  foregroundColor: cs.onPrimaryContainer,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Share something...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.mutedTextColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.photo_library_outlined,
                  color: cs.primary,
                  semanticLabel: 'Add photo or video',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
