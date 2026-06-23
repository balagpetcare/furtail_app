import 'package:flutter/material.dart';
import 'package:furtail_app/app/router/app_routes.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:image_picker/image_picker.dart';

import 'package:furtail_app/core/services/share_service.dart';

import '../../data/models/user_profile_model.dart';
import '../../data/profile_service.dart';
import '../../../pets/presentation/pet_create_screen.dart';
import '../../../pets/presentation/screens/pet_profile_screen.dart';
import 'profile_edit_overview_screen.dart';
import 'edit_about_details_screen.dart';

import '../widgets/achievements_section.dart';
import '../widgets/my_pets_family_white.dart';
import '../widgets/profile_completion_card.dart';
import '../widgets/profile_header_stack.dart';
import '../widgets/profile_highlights.dart';
import '../widgets/profile_media_upload_screen.dart';
import '../widgets/profile_status_composer.dart';
import '../widgets/profile_tab_about.dart';
import '../widgets/profile_tab_posts.dart';
import '../widgets/profile_tab_gallery.dart';
import '../widgets/profile_tab_more.dart';
import '../widgets/profile_tab_videos.dart';
import '../../../posts/presentation/screens/saved_posts_screen.dart';

/// New User Profile screen (white UI, stack header, achievements, tabs).
class UserProfileScreen extends StatefulWidget {
  final Future<void> Function()? onPetChanged;

  const UserProfileScreen({super.key, this.onPetChanged});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with TickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();

  UserProfileModel? _profile;
  bool _loading = true;
  String? _error;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final p = await _profileService.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async => _load();

  // ── Photo options bottom sheet ────────────────────────────────────────────

  Future<String?> _showPhotoOptions({required bool hasExisting}) {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(ctx).pop('gallery'),
            ),
            if (hasExisting)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove Photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.of(ctx).pop('remove'),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(ctx).pop(null),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _changeAvatar() async {
    final hasExisting = (_profile?.photoUrl ?? '').trim().isNotEmpty;
    final choice = await _showPhotoOptions(hasExisting: hasExisting);
    if (choice == null || !mounted) return;

    if (choice == 'remove') {
      try {
        final updated =
            await _profileService.updateProfile({'avatarMediaId': null});
        if (!mounted) return;
        setState(() => _profile = updated);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
      return;
    }

    final source =
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final result = await Navigator.push<ProfileMediaUploadResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileMediaUploadScreen(
          title: 'Update Profile Photo',
          cropStyle: ProfileCropStyle.avatar,
          initialSource: source,
        ),
      ),
    );
    if (result == null) return;

    setState(() =>
        _profile = _profile?.copyWith(photoUrl: result.previewUrl));

    try {
      final updated = await _profileService
          .updateProfile({'avatarMediaId': result.mediaId});
      if (!mounted) return;
      setState(() => _profile = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Profile photo update failed: ${e.toString().replaceAll('Exception: ', '')}')),
      );
      await _load();
    }
  }

  Future<void> _changeCover() async {
    final hasExisting = (_profile?.coverUrl ?? '').trim().isNotEmpty;
    final choice = await _showPhotoOptions(hasExisting: hasExisting);
    if (choice == null || !mounted) return;

    if (choice == 'remove') {
      try {
        final updated =
            await _profileService.updateProfile({'coverMediaId': null});
        if (!mounted) return;
        setState(() => _profile = updated);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
      return;
    }

    final source =
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final result = await Navigator.push<ProfileMediaUploadResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileMediaUploadScreen(
          title: 'Update Cover Photo',
          cropStyle: ProfileCropStyle.cover,
          initialSource: source,
        ),
      ),
    );
    if (result == null) return;

    setState(() =>
        _profile = _profile?.copyWith(coverUrl: result.previewUrl));

    try {
      final updated = await _profileService
          .updateProfile({'coverMediaId': result.mediaId});
      if (!mounted) return;
      setState(() => _profile = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Cover photo update failed: ${e.toString().replaceAll('Exception: ', '')}')),
      );
      await _load();
    }
  }

  void _openEditProfile() {
    final p = _profile;
    if (p == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ProfileEditOverviewScreen(initial: p)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Share profile',
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              final id = _profile?.id ?? 0;
              if (id <= 0) return;
              ShareService.share(context, type: 'user', id: id);
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (v) async {
              switch (v) {
                case 'edit':
                  _openEditProfile();
                  return;
                case 'avatar':
                  await _changeAvatar();
                  return;
                case 'cover':
                  await _changeCover();
                  return;
                case 'add_pet':
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PetCreateScreen()),
                  );
                  if (ok == true) {
                    await widget.onPetChanged?.call();
                    await _refresh();
                  }
                  return;
                default:
                  return;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                  value: 'edit',
                  child: _MenuRow(
                      icon: Icons.edit_rounded, label: 'Edit Profile')),
              PopupMenuItem(
                  value: 'avatar',
                  child: _MenuRow(
                      icon: Icons.account_circle_rounded,
                      label: 'Change Profile Photo')),
              PopupMenuItem(
                  value: 'cover',
                  child: _MenuRow(
                      icon: Icons.image_rounded,
                      label: 'Change Cover Photo')),
              PopupMenuDivider(),
              PopupMenuItem(
                  value: 'add_pet',
                  child: _MenuRow(
                      icon: Icons.pets_rounded, label: 'Add a Pet')),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: NestedScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverPersistentHeader(
                pinned: true,
                delegate:
                    _TabBarHeaderDelegate(child: _buildTabBar()),
              ),
            ],
            body: _profile == null
                ? const SizedBox()
                : TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      ProfileTabPosts(userId: _profile!.id),
                      ProfileTabAbout(
                        profile: _profile!,
                        onSeeMore: () async {
                          final ok = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditAboutDetailsScreen(
                                  initial: _profile!),
                            ),
                          );
                          if (ok == true) await _refresh();
                        },
                      ),
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ProfileTabGallery(
                          userId: _profile!.id,
                          canManage: true,
                        ),
                      ),
                      ProfileTabVideos(
                          userId: _profile!.id, canManage: true),
                      const SavedPostsList(),
                      const ProfileTabMore(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 520,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _errorView(_error!);
    }

    final p = _profile;
    if (p == null) return _errorView('Profile not found.');

    final completion = _computeProfileCompletion(p);
    final level = _levelFromPoints(p.points);
    final nextLevelPoints = _nextLevelPoints(level);
    final pointsToNext = (nextLevelPoints - p.points).clamp(0, pMax);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileHeaderStack(
          profile: p,
          batchText: 'Tier: ${p.tier ?? 'N/A'}',
          bioText: _bioOrDefault(p),
          onTapCoverCamera: _changeCover,
          onTapAvatarCamera: _changeAvatar,
          followerPreviewUrls: p.followerPreviewUrls,
          followersCount: p.followers,
          followingCount: p.following,
          onEditProfile: _openEditProfile,
          onAddPet: () async {
            final ok = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                  builder: (_) => const PetCreateScreen()),
            );
            if (ok == true) {
              await widget.onPetChanged?.call();
              await _load();
            }
          },
          onCreatePost: () =>
              Navigator.pushNamed(context, AppRoutes.createPost),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ProfileHighlights(
            onTapPinned: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pinned posts coming soon.')),
            ),
            onTapFeaturedPhotos: () => _tabController.animateTo(2),
            onTapInsights: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Insights coming soon.')),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ProfileCompletionCard(
            completionPercent: completion,
            levelText: 'Level $level',
            pointsText: '${p.points} Points',
            tipText: pointsToNext <= 0
                ? 'You are on top! Keep posting and earning awards.'
                : 'Earn $pointsToNext more points to reach the next level.',
          ),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AchievementsSection(points: p.points),
        ),

        const SizedBox(height: 12),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ProfileStatusComposer(),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MyPetsFamilyWhite(
            pets: p.pets,
            onTapPet: (pet) {
              final id = pet.id;
              if (id == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Pet ID missing. Please refresh.')),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PetProfileScreen(petId: id)),
              );
            },
            onAddNew: () async {
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => const PetCreateScreen()),
              );
              if (ok == true) {
                await widget.onPetChanged?.call();
                await _load();
              }
            },
          ),
        ),

        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.zero,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor:
            Theme.of(context).colorScheme.onSurfaceVariant,
        indicatorColor: Theme.of(context).colorScheme.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        labelStyle: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
        unselectedLabelStyle: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.normal),
        tabs: const [
          Tab(text: 'Posts'),
          Tab(text: 'About'),
          Tab(text: 'Gallery'),
          Tab(text: 'Videos'),
          Tab(text: 'Saved'),
          Tab(text: 'More'),
        ],
      ),
    );
  }

  Widget _errorView(String message) {
    return SizedBox(
      height: 520,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style:
                    AppTypography.bodyRegular(context, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static const int pMax = 1 << 30;

  static int _computeProfileCompletion(UserProfileModel p) {
    int score = 0;
    if (p.name.trim().isNotEmpty) score += 20;
    if ((p.username ?? '').trim().isNotEmpty) score += 10;
    if ((p.photoUrl ?? '').trim().isNotEmpty) score += 15;
    if ((p.coverUrl ?? '').trim().isNotEmpty) score += 10;
    if ((p.bio ?? '').trim().isNotEmpty) score += 15;
    if (p.pets.isNotEmpty) score += 30;
    return score.clamp(0, 100);
  }

  static int _levelFromPoints(int points) {
    if (points <= 0) return 1;
    if (points < 50) return 2;
    if (points < 150) return 3;
    if (points < 400) return 4;
    return 5;
  }

  static int _nextLevelPoints(int level) {
    switch (level) {
      case 1: return 1;
      case 2: return 50;
      case 3: return 150;
      case 4: return 400;
      default: return 800;
    }
  }

  static String _bioOrDefault(UserProfileModel p) {
    final b = (p.bio ?? '').trim();
    if (b.isNotEmpty) return b;
    return "Hi! I'm ${p.name}. I love sharing moments and connecting with pet lovers.";
  }
}

// ─── Tab bar delegate ─────────────────────────────────────────────────────────

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _TabBarHeaderDelegate({required this.child});

  @override double get minExtent => 48;
  @override double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(color: Colors.white, child: child);
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) => false;
}

// ─── Popup menu row ───────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}
