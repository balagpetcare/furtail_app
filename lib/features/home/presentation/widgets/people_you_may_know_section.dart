import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/app/router/app_routes.dart';
import 'package:furtail_app/core/theme/app_typography.dart';
import 'package:furtail_app/core/navigation/profile_navigation.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/features/social/data/models/people_discovery_user.dart';
import 'package:furtail_app/features/social/presentation/providers/people_discovery_providers.dart';
import 'package:furtail_app/features/social/presentation/widgets/shared_social_components.dart';

class PeopleYouMayKnowSection extends ConsumerWidget {
  const PeopleYouMayKnowSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      peopleDiscoveryProvider(PeopleDiscoveryKind.suggestions),
    );
    final controller = ref.read(
      peopleDiscoveryProvider(PeopleDiscoveryKind.suggestions).notifier,
    );
    final items = state.items.take(8).toList(growable: false);

    if (state.error != null && items.isEmpty) {
      return const SizedBox.shrink();
    }
    if (state.initialLoading && items.isEmpty) {
      return const _PeopleSkeletonStrip();
    }
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        0,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'People You May Know',
                    style: context.appText.titleMedium!.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.peopleHub),
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 180,
            child: ListView.separated(
              // Deliberately no PageStorageKey: this is a short preview
              // strip, not a scroll position worth remembering across
              // rebuilds/navigations — restoring a stale non-zero offset
              // here previously made the first card render clipped on the
              // left at "initial" load whenever an earlier offset had been
              // recorded in the same PageStorageBucket.
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final user = items[index];
                return _HomeSuggestionCard(
                  user: user,
                  busy: state.pendingActionUserIds.contains(user.id),
                  onFriendAction: () => controller.friendAction(user),
                  onFollowAction: () => controller.follow(user),
                  onDismiss: () => controller.dismiss(user),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSuggestionCard extends StatelessWidget {
  const _HomeSuggestionCard({
    required this.user,
    required this.busy,
    required this.onFriendAction,
    required this.onFollowAction,
    required this.onDismiss,
  });

  final PeopleDiscoveryUser user;
  final bool busy;
  final VoidCallback onFriendAction;
  final VoidCallback onFollowAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final friendLabel = user.hasIncomingRequest
        ? 'Accept'
        : user.hasOutgoingRequest
        ? 'Request Sent'
        : user.isFriend
        ? 'Friends'
        : 'Add Friend';
    final canCancel = user.hasOutgoingRequest;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double cardWidth = (screenWidth * 0.75).clamp(240.0, 320.0);

    return SizedBox(
      width: cardWidth,
      child: Card(
        elevation: 0,
        color: context.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: InkWell(
          onTap: () => ProfileNavigation.openUserProfile(context, user.id),
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SocialAvatar(
                              url: user.resolvedAvatarUrl(),
                              displayName: user.displayName,
                              radius: 24,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: SocialNameAndContext(
                                displayName: user.displayName,
                                username: user.username,
                                contextLabel: user.primaryContextLabel,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(
                              width: 24,
                            ), // Space for dismiss button
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: SocialPrimaryButton(
                            label: friendLabel,
                            onPressed: busy || canCancel || user.isFriend
                                ? null
                                : onFriendAction,
                          ),
                        ),
                        if (canCancel) ...[
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            icon: const Icon(Icons.close),
                            iconSize: 20,
                            onPressed: busy ? null : onFriendAction,
                            tooltip: 'Cancel Request',
                            color: cs.onSurfaceVariant,
                            style: IconButton.styleFrom(
                              backgroundColor: cs.surfaceContainerHighest,
                            ),
                          ),
                        ] else if (user.canFollow &&
                            !user.isFriend &&
                            !user.hasIncomingRequest &&
                            !user.hasOutgoingRequest) ...[
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            icon: Icon(
                              user.isFollowing
                                  ? Icons.how_to_reg
                                  : Icons.person_add_alt_1,
                            ),
                            iconSize: 20,
                            onPressed: busy ? null : onFollowAction,
                            tooltip: user.isFollowing ? 'Following' : 'Follow',
                            color: cs.onSurfaceVariant,
                            style: IconButton.styleFrom(
                              backgroundColor: cs.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: SocialDismissButton(onPressed: busy ? null : onDismiss),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeopleSkeletonStrip extends StatelessWidget {
  const _PeopleSkeletonStrip();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        0,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'People You May Know',
                    style: context.appText.titleMedium!.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(onPressed: null, child: const Text('See all')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 180,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double screenWidth = MediaQuery.sizeOf(context).width;
                final double cardWidth = (screenWidth * 0.75).clamp(
                  240.0,
                  320.0,
                );

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  itemCount: 3,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) => SizedBox(
                    width: cardWidth,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: context
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 14,
                                        width: 120,
                                        decoration: BoxDecoration(
                                          color: context
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        height: 10,
                                        width: 86,
                                        decoration: BoxDecoration(
                                          color: context
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: context
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: context
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ), // end Card
                  ), // end SizedBox
                ); // end ListView.separated
              }, // end builder
            ), // end LayoutBuilder
          ), // end SizedBox
        ],
      ),
    );
  }
}
