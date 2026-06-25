import 'package:furtail_app/app/router/app_routes.dart';
import 'package:furtail_app/core/analytics/analytics_provider.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/core/providers/current_user_provider.dart';

import '../cubit/visitor_profile_cubit.dart';
import '../cubit/visitor_profile_state.dart';
import '../widgets/visitor_profile_header_stack.dart';
import '../widgets/profile_tab_gallery.dart';
import '../widgets/profile_tab_posts.dart';
import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/features/posts/presentation/widgets/report_bottom_sheet.dart';
import 'package:furtail_app/core/widgets/app_state_widgets.dart';
import 'package:furtail_app/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:furtail_app/features/settings/data/models/blocked_user.dart';

/// Visitor profile should look almost identical to UserProfile,
/// but without any edit options.
class VisitorProfileScreen extends ConsumerStatefulWidget {
  final int userId;
  const VisitorProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<VisitorProfileScreen> createState() =>
      _VisitorProfileScreenState();
}

class _VisitorProfileScreenState extends ConsumerState<VisitorProfileScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  bool _profileViewLogged = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    final currentUser = ref.watch(currentUserProvider);
    final isSelf = currentUser.userId != null && userId == currentUser.userId;

    if (isSelf) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.profile);
        }
      });
      return Scaffold(
        backgroundColor: context.colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final state = ref.watch(visitorProfileProvider(userId));
    final ctrl = ref.read(visitorProfileProvider(userId).notifier);

    if (!_profileViewLogged && state.profile != null) {
      _profileViewLogged = true;
      ref
          .read(analyticsServiceProvider)
          .logProfileViewed(profileUserId: userId);
    }

    // Show SnackBar for action errors (accept/decline/follow failures)
    // without replacing the profile content with an error screen.
    ref.listen<VisitorProfileState>(visitorProfileProvider(userId), (
      prev,
      next,
    ) {
      if (next.error != null && next.profile != null && prev?.profile != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(next.error!),
                backgroundColor: context.colorScheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    });

    final cs = context.colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: RefreshIndicator(
          color: cs.primary,
          backgroundColor: cs.surface,
          onRefresh: () async => ctrl.load(userId),
          child: NestedScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              final showTabs = state.profile?.canViewFullProfile ?? true;
              return [
                SliverToBoxAdapter(child: _buildHeader(context, state, ctrl)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarHeaderDelegate(
                    height: showTabs ? 48 : 0,
                    child: showTabs ? _buildTabBar() : const SizedBox.shrink(),
                  ),
                ),
              ];
            },
            body: _buildBody(context, state, ctrl),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    VisitorProfileState state,
    VisitorProfileController ctrl,
  ) {
    if (state.loading) {
      return const Column(
        children: [
          AppSkeletonCard(height: 250, borderRadius: BorderRadius.zero),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AppSkeletonCard(height: 30),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: AppSkeletonCard(height: 48)),
                SizedBox(width: 8),
                Expanded(child: AppSkeletonCard(height: 48)),
                SizedBox(width: 8),
                Expanded(child: AppSkeletonCard(height: 48)),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
      );
    }

    if (state.error != null && state.profile == null) {
      return _errorView(state.error!, onRetry: () => ctrl.load(widget.userId));
    }

    final profile = state.profile;
    if (profile == null) {
      return _errorView(
        'Profile not found.',
        onRetry: () => ctrl.load(widget.userId),
      );
    }

    final userId = widget.userId;
    final currentUser = ref.read(currentUserProvider);
    final isSelf = currentUser.userId != null && userId == currentUser.userId;

    final followerPreview = profile.followerPreviewUrls;
    final cs = Theme.of(context).colorScheme;

    final status = state.status;
    final isFollowing = status?.isFollowing ?? false;
    final isFriend = status?.isFriend ?? false;
    final hasOutgoing = status?.outgoingRequestId != null;
    final hasIncoming = status?.incomingRequestId != null;
    final isFollowLoading = state.isFollowLoading;
    final isFriendLoading = state.isFriendLoading;

    final btnShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    const btnPad = EdgeInsets.symmetric(vertical: 12);

    // ── Follow / Following ──────────────────────────────────────────────────
    Widget followButton;
    if (isFollowLoading) {
      followButton = const ElevatedButton(
        onPressed: null,
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
        ),
      );
    } else if (isFollowing) {
      followButton = OutlinedButton.icon(
        onPressed: () => ctrl.toggleFollow(),
        icon: const Icon(Icons.check_rounded, size: 18),
        label: const Text('Following'),
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary),
          padding: btnPad,
          shape: btnShape,
        ),
      );
    } else {
      followButton = ElevatedButton.icon(
        onPressed: () => ctrl.toggleFollow(),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Follow'),
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          padding: btnPad,
          shape: btnShape,
          elevation: 0,
        ),
      );
    }

    // ── Friend action ───────────────────────────────────────────────────────
    Widget friendButton;
    if (isFriendLoading) {
      friendButton = const OutlinedButton(
        onPressed: null,
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
        ),
      );
    } else if (isFriend) {
      friendButton = OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.people_rounded, size: 18),
        label: const Text('Friends'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.green.shade700,
          side: BorderSide(color: Colors.green.shade600),
          padding: btnPad,
          shape: btnShape,
        ),
      );
    } else if (hasOutgoing) {
      friendButton = OutlinedButton.icon(
        onPressed: () => ctrl.friendAction(),
        icon: const Icon(Icons.person_remove_outlined, size: 18),
        label: const Text('Requested'),
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface.withValues(alpha: 0.6),
          side: BorderSide(color: cs.outline),
          padding: btnPad,
          shape: btnShape,
        ),
      );
    } else {
      friendButton = OutlinedButton.icon(
        onPressed: () => ctrl.friendAction(),
        icon: const Icon(Icons.person_add_outlined, size: 18),
        label: const Text('Add Friend'),
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary),
          padding: btnPad,
          shape: btnShape,
        ),
      );
    }

    // ── Accept / Decline (incoming request) ─────────────────────────────────
    final acceptButton = ElevatedButton.icon(
      onPressed: isFriendLoading ? null : () => ctrl.acceptIncoming(),
      icon: const Icon(Icons.check_rounded, size: 18),
      label: const Text('Accept'),
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        padding: btnPad,
        shape: btnShape,
        elevation: 0,
      ),
    );
    final declineButton = OutlinedButton.icon(
      onPressed: isFriendLoading ? null : () => ctrl.rejectIncoming(),
      icon: const Icon(Icons.close_rounded, size: 18),
      label: const Text('Decline'),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.error,
        side: BorderSide(color: cs.error),
        padding: btnPad,
        shape: btnShape,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VisitorProfileHeaderStack(
          profile: profile,
          bioText: (profile.bio ?? '').trim(),
          followerPreviewUrls: followerPreview,
          followersCount: profile.followersCount,
          followingCount: profile.followingCount,
          showBackButton: Navigator.canPop(context),
          onShare: () => ShareService.share(context, type: 'user', id: userId),
          moreActionsButton: PopupMenuButton<String>(
            tooltip: 'More options',
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0x73000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.more_horiz,
                color: Colors.white,
                size: 20,
              ),
            ),
            onSelected: (v) {
              if (v == 'report') {
                ReportBottomSheet.show(
                  context,
                  targetType: ReportTargetType.user,
                  targetId: userId,
                );
              } else if (v == 'block') {
                _blockUser(context, profile);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Report Profile',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block_rounded, size: 18, color: cs.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Block User',
                        style: TextStyle(
                          color: cs.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _statsRow(
            followers: profile.followersCount,
            following: profile.followingCount,
            pets: profile.petsCount,
          ),
        ),
        const SizedBox(height: 12),

        if (!isSelf) ...[
          // Primary row: Follow + Friend  ─OR─  Accept + Decline (incoming request)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: hasIncoming
                  ? [
                      Expanded(child: acceptButton),
                      const SizedBox(width: 8),
                      Expanded(child: declineButton),
                    ]
                  : [
                      Expanded(child: followButton),
                      const SizedBox(width: 8),
                      Expanded(child: friendButton),
                    ],
            ),
          ),
          const SizedBox(height: 8),

          // Message — always disabled, full width
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Tooltip(
              message: 'Messaging coming soon',
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    padding: btnPad,
                    shape: btnShape,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (profile.awards.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Awards',
              style: context.appText.bodyLarge!.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: profile.awards.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final a = profile.awards[i];
                return _AwardCard(title: a.title, iconUrl: a.iconUrl);
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    VisitorProfileState state,
    VisitorProfileController ctrl,
  ) {
    if (state.loading) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, _) => const AppPostSkeleton(),
      );
    }
    if (state.error != null) {
      return Center(child: Text(state.error!));
    }

    final profile = state.profile;
    if (profile == null) {
      return const Center(child: Text('No profile data found.'));
    }

    if (!profile.canViewFullProfile) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: context.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: context.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              child: Column(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 56,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This Profile is Private',
                    style: context.appText.bodyLarge!.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Follow or add friend to see their posts and details.',
                    textAlign: TextAlign.center,
                    style: context.appText.bodyMedium!.copyWith(
                      color: context.mutedTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (profile.pets.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Pets',
              style: context.appText.bodyLarge!.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ...profile.pets.map((p) => _VisitorPetsTab._petTile(context, p)),
          ],
        ],
      );
    }

    return TabBarView(
      controller: _tabController,
      physics: const BouncingScrollPhysics(),
      children: [
        ProfileTabPosts(userId: profile.id),
        _VisitorPetsTab(profile: profile),
        ProfileTabGallery(userId: profile.id, canManage: false),
        _VisitorTabAbout(profile: profile),
      ],
    );
  }

  Widget _buildTabBar() {
    final cs = context.colorScheme;
    return Container(
      color: cs.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: cs.onSurface,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary,
        tabs: const [
          Tab(text: 'Posts'),
          Tab(text: 'Pets'),
          Tab(text: 'Media'),
          Tab(text: 'About'),
        ],
      ),
    );
  }

  Widget _statsRow({
    required int followers,
    required int following,
    required int pets,
  }) {
    Widget chip(String label, int value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: context.colorScheme.outline),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: context.appText.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: context.appText.bodySmall!.copyWith(
                  color: context.mutedTextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('Followers', followers),
        const SizedBox(width: 10),
        chip('Following', following),
        const SizedBox(width: 10),
        chip('Pets', pets),
      ],
    );
  }

  Widget _errorView(String message, {required VoidCallback onRetry}) {
    return SizedBox(
      height: 420,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _blockUser(BuildContext context, dynamic profile) async {
    final userId = profile.id as int;
    final name = profile.displayName?.toString() ?? 'User';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block user?'),
        content: Text(
          '$name will no longer be able to find or interact with your profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    await SettingsLocalDatasource().blockUser(
      BlockedUser(userId: userId, displayName: name, blockedAt: DateTime.now()),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name blocked')));
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  _TabBarHeaderDelegate({required this.child, this.height = 48});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(_TabBarHeaderDelegate oldDelegate) =>
      oldDelegate.height != height;
}

class _AwardCard extends StatelessWidget {
  final String title;
  final String? iconUrl;
  const _AwardCard({required this.title, this.iconUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorScheme.outline),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: (iconUrl != null && iconUrl!.trim().isNotEmpty)
                ? Image.network(
                    iconUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    color: const Color(0xFFF3F3F3),
                    child: const Icon(Icons.emoji_events_rounded),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cardTitle(
                context,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// About tab for visitor — shows bio + public intro only.
/// Empty fields are hidden; sensitive fields (gender, religion, etc.) are never shown.
class _VisitorTabAbout extends StatelessWidget {
  final dynamic profile;
  const _VisitorTabAbout({required this.profile});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final bio = (profile.bio ?? '').toString().trim();
    final livesIn = (profile.placeLive ?? '').toString().trim();
    final from = (profile.from ?? '').toString().trim();
    final profType = (profile.profileType ?? '').toString().trim();
    final work = (profile.workStatus ?? '').toString().trim();
    final edu = (profile.education ?? '').toString().trim();

    final hasIntro =
        livesIn.isNotEmpty ||
        from.isNotEmpty ||
        profType.isNotEmpty ||
        work.isNotEmpty ||
        edu.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (bio.isNotEmpty) ...[
          Text(
            'Bio',
            style: context.appText.bodyLarge!.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              bio,
              style: AppTypography.bodyRegular(context).copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (hasIntro) ...[
          Text(
            'Intro',
            style: context.appText.bodyLarge!.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              children: [
                if (profType.isNotEmpty)
                  _iconRow(
                    context,
                    Icons.person_outline,
                    'Profile type: $profType',
                  ),
                if (livesIn.isNotEmpty)
                  _iconRow(context, Icons.home_outlined, 'Lives in $livesIn'),
                if (from.isNotEmpty)
                  _iconRow(context, Icons.location_on_outlined, 'From $from'),
                if (work.isNotEmpty)
                  _iconRow(context, Icons.work_outline, work),
                if (edu.isNotEmpty)
                  _iconRow(context, Icons.school_outlined, 'Studied at $edu'),
              ],
            ),
          ),
        ] else if (bio.isEmpty) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Nothing to see here yet.',
                style: TextStyle(
                  color: context.mutedTextColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
      ],
    );
  }

  static Widget _iconRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.mutedTextColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: AppTypography.bodyRegular(context)),
          ),
        ],
      ),
    );
  }
}

/// Pets tab for visitor profile.
class _VisitorPetsTab extends StatelessWidget {
  final dynamic profile;
  const _VisitorPetsTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    final pets = (profile.pets as List?) ?? [];
    if (pets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pets_rounded,
                size: 72,
                color: context.colorScheme.primary.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 16),
              const Text(
                'No pets yet',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: 8),
              Text(
                'This user hasn\'t added any pets yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.mutedTextColor),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: pets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (ctx, i) => _petTile(ctx, pets[i]),
    );
  }

  static Widget _petTile(BuildContext context, dynamic p) {
    final petId = (p.id is int) ? (p.id as int) : 0;
    final hasPhoto = (p.photoUrl ?? '').toString().trim().isNotEmpty;
    final followers = (p.followersCount as int?) ?? 0;
    final likes = (p.likesCount as int?) ?? 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: hasPhoto ? NetworkImage(p.photoUrl.toString()) : null,
        child: hasPhoto
            ? null
            : const Icon(Icons.pets, color: Colors.grey, size: 22),
      ),
      title: Text(
        (p.name ?? 'Pet').toString(),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text((p.animalTypeName ?? '').toString()),
          if (followers > 0 || likes > 0)
            Text(
              '$followers followers · $likes likes',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        if (petId <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pet profile not available')),
          );
          return;
        }
        Navigator.pushNamed(
          context,
          AppRoutes.petPublicProfile,
          arguments: {'petId': petId},
        );
      },
    );
  }
}
