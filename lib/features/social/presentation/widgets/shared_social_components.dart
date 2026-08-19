import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';

/// The canonical avatar for social lists and cards (Friends/Suggestions/
/// Requests) — a thin wrapper around [FurtailNetworkAvatar] so every
/// identity row in the app (Messages, Notifications, Friends) shares the
/// exact same real-photo-vs-initials-fallback behavior instead of each
/// feature rolling its own. Never falls back to a tiny generic icon in an
/// oversized empty circle: a missing photo always renders a large,
/// legible initial instead.
class SocialAvatar extends StatelessWidget {
  const SocialAvatar({
    super.key,
    required this.url,
    required this.displayName,
    this.radius = 28.0,
  });

  final String? url;
  final String displayName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return FurtailNetworkAvatar(
      imageUrl: url,
      displayName: displayName,
      radius: radius,
      backgroundColor: cs.primaryContainer,
      foregroundColor: cs.onPrimaryContainer,
    );
  }
}

/// A reusable component for social names and usernames.
class SocialNameAndContext extends StatelessWidget {
  const SocialNameAndContext({
    super.key,
    required this.displayName,
    this.username,
    this.contextLabel,
    this.postsCount,
    this.maxLines = 1,
  });

  final String displayName;
  final String? username;
  final String? contextLabel;
  final int? postsCount;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ),
            if (postsCount != null && postsCount! > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _formatPostsCount(postsCount!),
                  style: textTheme.labelSmall?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (username != null && username!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            '@$username',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: context.mutedTextColor),
          ),
        ],
        if (contextLabel != null && contextLabel!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            contextLabel!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: context.mutedTextColor),
          ),
        ],
      ],
    );
  }

  String _formatPostsCount(int count) {
    if (count == 1) return '1 post';
    return '$count posts';
  }
}

/// Primary button for social actions (Add Friend, Accept, etc.)
class SocialPrimaryButton extends StatelessWidget {
  const SocialPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final style = FilledButton.styleFrom(
      backgroundColor: isDestructive ? cs.error : cs.primary,
      foregroundColor: isDestructive ? cs.onError : cs.onPrimary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      minimumSize: const Size(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
    );

    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: style,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Secondary button for social actions (Follow, Following, etc.)
class SocialSecondaryButton extends StatelessWidget {
  const SocialSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final style = OutlinedButton.styleFrom(
      foregroundColor: isDestructive ? cs.error : cs.primary,
      side: BorderSide(color: isDestructive ? cs.error : cs.outline),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      minimumSize: const Size(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
    );

    if (icon != null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: style,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Dismiss button for suggestions.
class SocialDismissButton extends StatelessWidget {
  const SocialDismissButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            Icons.close_rounded,
            size: 16,
            color: context.mutedTextColor,
          ),
        ),
      ),
    );
  }
}

/// Reusable social UI helpers.
abstract class SocialUiHelpers {
  static String formatFriendsCount(int count) {
    if (count == 1) return '1 friend';
    return '$count friends';
  }
}
