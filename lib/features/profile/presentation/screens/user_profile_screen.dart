import 'package:flutter/material.dart';

import 'package:furtail_app/core/services/share_service.dart';

import '../../data/models/user_profile_model.dart';
import '../../data/profile_service.dart';
import '../../../pets/presentation/pet_create_screen.dart';
import '../../../pets/presentation/screens/pet_profile_screen.dart';
import 'profile_edit_overview_screen.dart';
import 'edit_about_details_screen.dart';

import '../widgets/achievements_section.dart';
import '../widgets/my_pets_family_white.dart';
import '../widgets/posts_placeholder.dart';
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

/// New User Profile screen (white UI, stack header, achievements, tabs).
/// All UI text is in English.
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
    _tabController = TabController(length: 5, vsync: this);
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

  /// ✅ FIX: `_refresh()` was missing. Use it everywhere you need quick reload.
  Future<void> _refresh() async {
    await _load();
  }

  Future<void> _changeAvatar() async {
    final result = await Navigator.push<ProfileMediaUploadResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileMediaUploadScreen(
          title: 'Update Profile Photo',
          cropStyle: ProfileCropStyle.avatar,
        ),
      ),
    );
    if (result == null) return;

    // ✅ Optimistic preview (local file)
    setState(() => _profile = _profile?.copyWith(photoUrl: result.previewUrl));

    try {
      final updated = await _profileService.updateProfile({
        'avatarMediaId': result.mediaId,
      });
      if (!mounted) return;
      // ✅ Immediately update state with server response (with cache bust)
      setState(() => _profile = updated);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile photo update failed / প্রোফাইল ছবি আপডেট ব্যর্থ হয়েছে\n$msg',
          ),
        ),
      );
      await _load();
    }
  }

  Future<void> _changeCover() async {
    final result = await Navigator.push<ProfileMediaUploadResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileMediaUploadScreen(
          title: 'Update Cover Photo',
          cropStyle: ProfileCropStyle.cover,
        ),
      ),
    );
    if (result == null) return;

    // ✅ Optimistic preview (local file)
    setState(() => _profile = _profile?.copyWith(coverUrl: result.previewUrl));

    try {
      final updated = await _profileService.updateProfile({
        'coverMediaId': result.mediaId,
      });
      if (!mounted) return;
      // ✅ Immediately update state with server response (with cache bust)
      setState(() => _profile = updated);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cover photo update failed / কভার ছবি আপডেট ব্যর্থ হয়েছে\n$msg',
          ),
        ),
      );
      await _load();
    }
  }

  void _openEditProfile() {
    final p =
        _profile; // আপনার state-এ যে UserProfileModel? আছে (বা profile/currentProfile)
    if (p == null) return; // বা একটা snackbar দেখাতে পারেন

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileEditOverviewScreen(initial: p)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
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
                    MaterialPageRoute(builder: (_) => const PetCreateScreen()),
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
              PopupMenuItem(value: 'edit', child: _MenuRow(icon: Icons.edit_rounded, label: 'Edit Profile')),
              PopupMenuItem(value: 'avatar', child: _MenuRow(icon: Icons.account_circle_rounded, label: 'Change Profile Photo')),
              PopupMenuItem(value: 'cover', child: _MenuRow(icon: Icons.image_rounded, label: 'Change Cover Photo')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'add_pet', child: _MenuRow(icon: Icons.pets_rounded, label: 'Add a Pet')),
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
                delegate: _TabBarHeaderDelegate(child: _buildTabBar()),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: [
                ProfileTabPosts(userId: _profile?.id ?? 0),
                ProfileTabAbout(
                  profile: _profile!,
                  onSeeMore: () async {
                    final ok = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EditAboutDetailsScreen(initial: _profile!),
                      ),
                    );
                    if (ok == true) {
                      await _refresh();
                    }
                  },
                ),
                // Gallery widget is not scrollable by itself (Column) → wrap.
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ProfileTabGallery(
                    userId: _profile?.id ?? 0,
                    canManage: true,
                  ),
                ),
                ProfileTabVideos(userId: _profile?.id ?? 0, canManage: true),
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
          batchText: "Tier: ${p.tier ?? 'N/A'}",
          bioText: _bioOrDefault(p),
          onTapCoverCamera: _changeCover,
          onTapAvatarCamera: _changeAvatar,
          followerPreviewUrls: p.followerPreviewUrls,
          followersCount: p.followers,
          followingCount: p.following,
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ProfileHighlights(
            onTapPinned: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pinned posts coming soon.')),
              );
            },
            onTapFeaturedPhotos: () {
              _tabController.animateTo(1);
            },
            onTapInsights: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Insights coming soon.')),
              );
            },
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
                    content: Text('Pet ID missing. Please refresh.'),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PetProfileScreen(petId: id)),
              );
            },
            onAddNew: () async {
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const PetCreateScreen()),
              );
              if (ok == true) {
                await widget.onPetChanged?.call();
                await _load();
              }
            },
          ),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PostsPlaceholder(onEditProfile: _openEditProfile),
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      // বাম পাশের প্যাডিং ০ করে দিলে একদম স্ক্রিনের মাথা থেকে শুরু হবে
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        // এই লাইনটি ট্যাবগুলোকে বাম দিক থেকে শুরু করতে বাধ্য করবে
        tabAlignment: TabAlignment.start,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.black54,
        indicatorColor: Colors.black,
        indicatorWeight: 2,
        // ট্যাবগুলোর মাঝের বাড়তি গ্যাপ কমাতে চাইলে labelPadding ব্যবহার করতে পারেন
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        tabs: const [
          Tab(text: 'Posts'),
          Tab(text: 'About'),
          Tab(text: 'Galleries'),
          Tab(text: 'Videos'),
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
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      ),
    );
  }

  // -----------------------
  // Helpers (client-side)
  // -----------------------

  static const int pMax = 1 << 30;

  static int _computeProfileCompletion(UserProfileModel p) {
    int score = 0;
    if ((p.name).trim().isNotEmpty) score += 20;
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
      case 1:
        return 1;
      case 2:
        return 50;
      case 3:
        return 150;
      case 4:
        return 400;
      default:
        return 800;
    }
  }

  static String _defaultBioIfMissing(UserProfileModel p) {
    return "Hi! I'm ${p.name}. I love sharing moments, learning new things, and connecting with pet lovers. "
        "Follow along to see updates, celebrate achievements, and make every day a little better.";
  }

  static String _bioOrDefault(UserProfileModel p) {
    final b = (p.bio ?? '').trim();
    if (b.isNotEmpty) return b;
    return _defaultBioIfMissing(p);
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
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(color: Colors.white, child: child);
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) => false;
}

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
