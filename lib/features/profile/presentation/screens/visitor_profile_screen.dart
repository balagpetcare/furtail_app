import 'package:furtail_app/core/analytics/analytics_provider.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cubit/visitor_profile_cubit.dart';
import '../cubit/visitor_profile_state.dart';
import '../widgets/visitor_profile_header_stack.dart';
import '../widgets/profile_tab_gallery.dart';
import '../widgets/profile_tab_videos.dart';
import 'package:furtail_app/features/pets/presentation/screens/pet_profile_screen.dart';
import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/features/posts/presentation/widgets/report_bottom_sheet.dart';

/// Visitor profile should look almost identical to UserProfile,
/// but without any edit options.
class VisitorProfileScreen extends ConsumerStatefulWidget {
  final int userId;
  const VisitorProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<VisitorProfileScreen> createState() => _VisitorProfileScreenState();
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
    final state = ref.watch(visitorProfileProvider(userId));
    final ctrl = ref.read(visitorProfileProvider(userId).notifier);

    if (!_profileViewLogged && state.profile != null) {
      _profileViewLogged = true;
      ref.read(analyticsServiceProvider).logProfileViewed(profileUserId: userId);
    }

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
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                pinned: true,
                floating: false,
                backgroundColor: cs.surface,
                surfaceTintColor: cs.surface,
                foregroundColor: cs.onSurface,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                ),
                title: const Text('Profile'),
                actions: [
                  IconButton(
                    tooltip: 'Share',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => ShareService.share(context, type: 'user', id: userId),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'report') {
                        ReportBottomSheet.show(
                          context,
                          targetType: ReportTargetType.user,
                          targetId: userId,
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'report', child: Text('Report')),
                    ],
                  ),
                ],
              ),
              SliverToBoxAdapter(child: _buildHeader(context, state, ctrl)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarHeaderDelegate(child: _buildTabBar()),
              ),
            ],
            body: _buildBody(context, state, ctrl),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, VisitorProfileState state, VisitorProfileController ctrl) {
    if (state.loading) {
      return const SizedBox(height: 520, child: Center(child: CircularProgressIndicator()));
    }

    if (state.error != null) {
      return _errorView(state.error!, onRetry: () => ctrl.load(widget.userId));
    }

    final profile = state.profile;
    if (profile == null) {
      return _errorView('Profile not found.', onRetry: () => ctrl.load(widget.userId));
    }

    // Fake follower preview until backend provides real preview.
    final followerPreview = const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VisitorProfileHeaderStack(
          profile: profile,
          bioText: (profile.bio ?? '').trim(),
          followerPreviewUrls: followerPreview,
          followersCount: profile.followersCount,
          followingCount: profile.followingCount,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => ctrl.toggleFollow(),
                  child: const Text('Follow'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => ctrl.toggleLikeProfile(),
                icon: const Icon(Icons.favorite_border),
                label: const Text('Like'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (profile.awards.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Awards', style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: profile.awards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
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

  Widget _buildBody(BuildContext context, VisitorProfileState state, VisitorProfileController ctrl) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(child: Text(state.error!));
    }

    final profile = state.profile;
    if (profile == null) {
      return const Center(child: Text('No profile data found.'));
    }

    return TabBarView(
      controller: _tabController,
      physics: const BouncingScrollPhysics(),
      children: [
        _VisitorTabAbout(profile: profile),
        ProfileTabGallery(userId: profile.id, canManage: false),
        ProfileTabVideos(userId: profile.id, canManage: false),
        _VisitorTabMore(profile: profile),
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
          Tab(text: 'About'),
          Tab(text: 'Gallery'),
          Tab(text: 'Videos'),
          Tab(text: 'More'),
        ],
      ),
    );
  }

  Widget _statsRow({required int followers, required int following, required int pets}) {
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
              Text('$value', style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label, style: context.appText.bodySmall!.copyWith(color: context.mutedTextColor)),
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
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _TabBarHeaderDelegate({required this.child});

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(_TabBarHeaderDelegate oldDelegate) => false;
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
                ? Image.network(iconUrl!, width: 44, height: 44, fit: BoxFit.cover)
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
              style: AppTypography.cardTitle(context).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitorTabAbout extends StatelessWidget {
  final dynamic profile;
  const _VisitorTabAbout({required this.profile});

  String _fmtDate(DateTime? d) {
    if (d == null) return 'Not set';
    return "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final bio = (profile.bio ?? '').toString().trim();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('About', style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        _row(context, 'Bio', bio.isEmpty ? 'No bio added yet.' : bio),
        _row(context, 'Education', (profile.education ?? 'Not set').toString()),
        _row(context, 'Place live', (profile.placeLive ?? 'Not set').toString()),
        _row(context, 'Fans and friends', (profile.fansAndFriends ?? 'Not set').toString()),
        _row(context, 'From', (profile.from ?? 'Not set').toString()),
        _row(context, 'Profile type', (profile.profileType ?? 'Not set').toString()),
        _row(context, 'Work status', (profile.workStatus ?? 'Not set').toString()),
        _row(context, 'Religious status', (profile.religiousStatus ?? 'Not set').toString()),
        _row(context, 'Gender', (profile.gender ?? 'Not set').toString()),
        _row(context, 'Birthdate', _fmtDate(profile.birthdate)),
        _row(context, 'Marital status', (profile.maritalStatus ?? 'Not set').toString()),
        const SizedBox(height: 16),
        Text('Pets', style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        if ((profile.pets as List).isEmpty)
          const Text('No pets found.')
        else
          ...List.generate((profile.pets as List).length, (i) {
            final p = (profile.pets as List)[i];
            return _petTile(context, p);
          }),
      ],
    );
  }

  Widget _row(BuildContext context, String k, String v) {
    final vv = v.trim().isEmpty ? 'Not set' : v;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: AppTypography.bodyRegular(context).copyWith(fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Expanded(child: Text(vv, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _petTile(BuildContext context, dynamic p) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text((p.name ?? 'Pet').toString()),
      subtitle: Text((p.animalTypeName ?? '').toString()),
      onTap: () {},
    );
  }
}

class _VisitorTabGallery extends StatelessWidget {
  final List<String> urls;
  const _VisitorTabGallery({required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return const Center(child: Text('No gallery items.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: urls.length,
      itemBuilder: (context, i) {
        final url = urls[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(url, fit: BoxFit.cover),
        );
      },
    );
  }
}

class _VisitorTabVideos extends StatelessWidget {
  const _VisitorTabVideos();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Videos coming soon.'));
  }
}

class _VisitorTabMore extends StatelessWidget {
  final dynamic profile;
  const _VisitorTabMore({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('More', style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.share_rounded),
          title: const Text('Share profile'),
          onTap: () {
            Navigator.pop(context);
            ShareService.share(context, type: 'user', id: profile.id);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.flag_rounded),
          title: const Text('Report user'),
          onTap: () {
            Navigator.pop(context);
            ReportBottomSheet.show(
              context,
              targetType: ReportTargetType.user,
              targetId: profile.id,
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.block_rounded),
          title: const Text('Block user'),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Block coming soon.')),
            );
          },
        ),
      ],
    );
  }
}
