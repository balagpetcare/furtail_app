import 'package:flutter/material.dart';

import 'package:furtail_app/core/navigation/profile_navigation.dart';
import 'package:furtail_app/core/media/media_url.dart';
import 'package:furtail_app/features/profile/data/models/visitor_profile_model.dart';
import 'package:furtail_app/core/theme/spacing.dart';

import '../../data/models/presence_info.dart';
import '../../data/models/social_user_summary.dart';
import 'presence_dot.dart';
import 'shared_social_components.dart';

/// One row in a Social hub list: avatar, name/username, and up to two
/// contextual action buttons. Tapping the row (outside the buttons)
/// navigates to that user's profile via the app's existing
/// [ProfileNavigation] helper.
class SocialUserTile extends StatelessWidget {
  const SocialUserTile({
    super.key,
    required this.user,
    this.primaryLabel,
    this.onPrimary,
    this.primaryIsDestructive = false,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
    this.trailing,
    this.contextLabel,
    this.avatarRadius = 28,
    this.presence,
  });

  final SocialUserSummary user;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryIsDestructive;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;

  /// Overrides the default primary/secondary text-button pair with a
  /// custom trailing widget — used by the Friends row, which wants a
  /// compact Message icon + overflow "More" menu instead of two
  /// text buttons (Remove Friend lives inside the More menu, not as a
  /// standalone destructive button on every row).
  final Widget? trailing;

  /// Optional context line (e.g. mutual friends, location) shown under the
  /// username, when the API actually supplies it.
  final String? contextLabel;

  final double avatarRadius;

  /// Active Status for this row's user, when the caller has it (currently
  /// only the Friends list fetches presence) — shows a green dot on the
  /// avatar and an "Active now"/"Active Xm ago" line under the name. Left
  /// null anywhere presence doesn't apply (Suggestions/Requests/Followers),
  /// which renders exactly as before.
  final PresenceInfo? presence;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => ProfileNavigation.openUserProfile(
        context,
        user.id,
        preview: VisitorProfilePreview(
          id: user.id,
          displayName: user.displayName,
          username: user.username,
          avatarUrl: user.avatarUrl,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            PresenceAvatar(
              url: user.resolvedAvatarUrl(MediaUse.thumbnail),
              displayName: user.displayName,
              radius: avatarRadius,
              isOnline: presence?.isOnline ?? false,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SocialNameAndContext(
                    displayName: user.displayName,
                    username: user.username,
                    contextLabel: contextLabel,
                  ),
                  if (presence != null)
                    PresenceStatusLabel(presence: presence!),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (trailing != null)
              trailing!
            else ...[
              if (secondaryLabel != null && onSecondary != null)
                SocialSecondaryButton(
                  label: secondaryLabel!,
                  onPressed: onSecondary,
                  isDestructive: false,
                ),
              if (secondaryLabel != null &&
                  onSecondary != null &&
                  primaryLabel != null)
                const SizedBox(width: AppSpacing.sm),
              if (primaryLabel != null)
                SocialPrimaryButton(
                  label: primaryLabel!,
                  onPressed: onPrimary,
                  isDestructive: primaryIsDestructive,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
