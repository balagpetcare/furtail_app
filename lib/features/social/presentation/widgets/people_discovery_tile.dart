import 'package:flutter/material.dart';

import 'package:furtail_app/core/navigation/profile_navigation.dart';
import 'package:furtail_app/core/media/media_url.dart';
import 'package:furtail_app/features/profile/data/models/visitor_profile_model.dart';

import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/features/social/data/models/people_discovery_user.dart';

import 'shared_social_components.dart';

class PeopleDiscoveryTile extends StatelessWidget {
  const PeopleDiscoveryTile({
    super.key,
    required this.user,
    required this.busy,
    required this.onFriendAction,
    required this.onFollowAction,
    this.onDismiss,
  });

  final PeopleDiscoveryUser user;
  final bool busy;
  final VoidCallback onFriendAction;
  final VoidCallback onFollowAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final friendlyMeta = user.mutualContextLabel;
    final location = user.locationLabel;

    final contextLabel = [
      if (friendlyMeta != null && friendlyMeta.trim().isNotEmpty) friendlyMeta,
      if (location != null && location.trim().isNotEmpty) location,
      if ((user.bio ?? '').trim().isNotEmpty) user.bio!.trim(),
    ].join(' • ');

    final friendLabel = user.hasIncomingRequest
        ? 'Accept'
        : user.hasOutgoingRequest
        ? 'Request Sent'
        : user.isFriend
        ? 'Friends'
        : 'Add Friend';

    final followLabel = user.isFollowing ? 'Following' : 'Follow';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(right: onDismiss != null ? 36 : 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SocialAvatar(
                        url: user.resolvedAvatarUrl(MediaUse.thumbnail),
                        displayName: user.displayName,
                        radius: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SocialNameAndContext(
                              displayName: user.displayName,
                              username: user.username,
                              contextLabel: contextLabel,
                              postsCount: user.publicActivityCount,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                SocialPrimaryButton(
                                  label: friendLabel,
                                  onPressed: busy ? null : onFriendAction,
                                ),
                                SocialSecondaryButton(
                                  label: followLabel,
                                  onPressed: busy || !user.interactionAllowed
                                      ? null
                                      : onFollowAction,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: context.mutedTextColor,
                      onPressed: busy ? null : onDismiss,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, indent: 72),
      ],
    );
  }
}
