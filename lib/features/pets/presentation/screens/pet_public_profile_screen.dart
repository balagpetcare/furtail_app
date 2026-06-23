import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pet_service.dart';
import '../../data/models/pet_model.dart';
import '../pet_profile_wizard_screen.dart';

// ── State ────────────────────────────────────────────────────────────────────

final _petService = PetService();

class _PetPublicState {
  final PetModel? pet;
  final List<Map<String, dynamic>> posts;
  final bool loading;
  final bool loadingPosts;
  final String? error;
  final bool isFollowing;
  final bool isLiked;
  final bool isOwner;
  final String activeTab;

  const _PetPublicState({
    this.pet,
    this.posts = const [],
    this.loading = true,
    this.loadingPosts = false,
    this.error,
    this.isFollowing = false,
    this.isLiked = false,
    this.isOwner = false,
    this.activeTab = 'posts',
  });

  _PetPublicState copyWith({
    PetModel? pet,
    List<Map<String, dynamic>>? posts,
    bool? loading,
    bool? loadingPosts,
    String? error,
    bool? isFollowing,
    bool? isLiked,
    bool? isOwner,
    String? activeTab,
  }) =>
      _PetPublicState(
        pet: pet ?? this.pet,
        posts: posts ?? this.posts,
        loading: loading ?? this.loading,
        loadingPosts: loadingPosts ?? this.loadingPosts,
        error: error,
        isFollowing: isFollowing ?? this.isFollowing,
        isLiked: isLiked ?? this.isLiked,
        isOwner: isOwner ?? this.isOwner,
        activeTab: activeTab ?? this.activeTab,
      );
}

class _PetPublicNotifier extends StateNotifier<_PetPublicState> {
  final int petId;
  _PetPublicNotifier(this.petId) : super(const _PetPublicState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final pet = await _petService.getPublicPet(petId);
      Map<String, dynamic> socialStatus = {};
      try {
        socialStatus = await _petService.getPetSocialStatus(petId);
      } catch (_) {}

      state = state.copyWith(
        pet: pet as PetModel,
        loading: false,
        isFollowing:
            (socialStatus['isFollowing'] ?? pet.isFollowing) == true,
        isLiked: (socialStatus['isLiked'] ?? pet.isLiked) == true,
        isOwner: (socialStatus['isOwner'] ?? pet.isOwner) == true,
      );
      await _loadPosts();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> _loadPosts() async {
    state = state.copyWith(loadingPosts: true, error: null);
    try {
      final posts = await _petService.getPetPosts(petId);
      state = state.copyWith(posts: posts, loadingPosts: false);
    } catch (e) {
      state = state.copyWith(loadingPosts: false, error: e.toString());
    }
  }

  Future<void> toggleFollow() async {
    final was = state.isFollowing;
    state = state.copyWith(isFollowing: !was);
    try {
      was
          ? await _petService.unfollowPet(petId)
          : await _petService.followPet(petId);
    } catch (e) {
      state = state.copyWith(isFollowing: was, error: e.toString());
    }
  }

  Future<void> toggleLike() async {
    final was = state.isLiked;
    state = state.copyWith(isLiked: !was);
    try {
      was
          ? await _petService.unlikePet(petId)
          : await _petService.likePet(petId);
    } catch (e) {
      state = state.copyWith(isLiked: was, error: e.toString());
    }
  }

  void setTab(String tab) => state = state.copyWith(activeTab: tab);
  Future<void> refresh() => _load();
}

final _petPublicProvider = StateNotifierProvider.autoDispose
    .family<_PetPublicNotifier, _PetPublicState, int>(
  (ref, petId) => _PetPublicNotifier(petId),
);

// ── Screen ───────────────────────────────────────────────────────────────────

class PetPublicProfileScreen extends ConsumerWidget {
  final int petId;
  const PetPublicProfileScreen({super.key, required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_petPublicProvider(petId));
    final notifier = ref.read(_petPublicProvider(petId).notifier);

    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.error != null && state.pet == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(state.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: notifier.refresh,
                  child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final pet = state.pet!;
    const tabs = ['Posts', 'About', 'Health'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: CustomScrollView(
          slivers: [
            // ── Cover + Avatar ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: pet.coverMediaUrl != null
                        ? Image.network(pet.coverMediaUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _GradientCover(name: pet.name))
                        : _GradientCover(name: pet.name),
                  ),
                  Positioned(
                    top: 48,
                    left: 16,
                    child: _BackButton(onTap: () => Navigator.pop(context)),
                  ),
                  Positioned(
                    bottom: -42,
                    left: 20,
                    child: _AvatarBadge(photoUrl: pet.photoUrl),
                  ),
                ],
              ),
            ),

            // ── Name + Edit button ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pet.name,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1A2E))),
                          if (_petSubtitle(pet).isNotEmpty)
                            Text(_petSubtitle(pet),
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[600])),
                          if (pet.slug != null)
                            Text('@${pet.slug}',
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF4C6EF5))),
                        ],
                      ),
                    ),
                    if (state.isOwner)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4C6EF5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PetProfileWizardScreen(petId: petId),
                            ),
                          );
                          if (result == true) notifier.refresh();
                        },
                      ),
                  ],
                ),
              ),
            ),

            // ── Stats ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _StatChip(Icons.favorite_outline, pet.likesCount ?? 0,
                        'Likes'),
                    _StatChip(Icons.people_outline, pet.followersCount ?? 0,
                        'Followers'),
                    _StatChip(Icons.article_outlined, state.posts.length,
                        'Posts'),
                  ],
                ),
              ),
            ),

            // ── Social buttons (visitors only) ──────────────────────────
            if (!state.isOwner)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SocialButton(
                          label: state.isFollowing ? 'Following' : 'Follow',
                          icon: state.isFollowing
                              ? Icons.check
                              : Icons.person_add_outlined,
                          active: state.isFollowing,
                          onTap: notifier.toggleFollow,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SocialButton(
                          label: state.isLiked ? 'Liked' : 'Like',
                          icon: state.isLiked
                              ? Icons.favorite
                              : Icons.favorite_outline,
                          active: state.isLiked,
                          activeColor: Colors.pink,
                          onTap: notifier.toggleLike,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Bio ─────────────────────────────────────────────────────
            if (pet.bio != null && pet.bio!.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(pet.bio!,
                        style: TextStyle(
                            color: Colors.grey[700], fontSize: 14)),
                  ),
                ),
              ),

            // ── Tabs ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  color: Colors.white,
                  child: Row(
                    children: tabs.map((tab) {
                      final active =
                          state.activeTab == tab.toLowerCase();
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              notifier.setTab(tab.toLowerCase()),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: active
                                      ? const Color(0xFF4C6EF5)
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Text(
                              tab,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: active
                                    ? const Color(0xFF4C6EF5)
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // ── Tab content ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _tabContent(state, pet),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  String _petSubtitle(PetModel pet) {
    return <String?>[pet.animalTypeName, pet.breedName]
        .where((s) => s != null && s!.isNotEmpty)
        .whereType<String>()
        .join(' · ');
  }

  Widget _tabContent(_PetPublicState state, PetModel pet) {
    switch (state.activeTab) {
      case 'about':
        return _AboutSection(pet: pet);
      case 'health':
        return _HealthSection(pet: pet);
      default:
        return _PostsSection(
          posts: state.posts,
          loading: state.loadingPosts,
          isOwner: state.isOwner,
        );
    }
  }
}

// ── Reusable Widgets ─────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  final String? photoUrl;
  const _AvatarBadge({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)
        ],
      ),
      child: CircleAvatar(
        radius: 42,
        backgroundColor: const Color(0xFF4C6EF5),
        backgroundImage:
            photoUrl != null ? NetworkImage(photoUrl!) : null,
        child: photoUrl == null
            ? const Icon(Icons.pets, size: 36, color: Colors.white)
            : null,
      ),
    );
  }
}

class _GradientCover extends StatelessWidget {
  final String name;
  const _GradientCover({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4C6EF5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.pets,
            size: 60, color: Colors.white.withOpacity(0.3)),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  const _StatChip(this.icon, this.count, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF4C6EF5)),
          const SizedBox(width: 6),
          Text('$count $label',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E))),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? const Color(0xFF4C6EF5);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18, color: active ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: active ? Colors.white : color,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Posts Section ─────────────────────────────────────────────────────────────

class _PostsSection extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool loading;
  final bool isOwner;

  const _PostsSection({
    required this.posts,
    required this.loading,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.article_outlined, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('No posts yet',
                  style:
                      TextStyle(color: Colors.grey[600], fontSize: 16)),
              if (isOwner)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Share an update from your pet!',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 13)),
                ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: posts.map((p) => _PostCard(post: p)).toList(),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final caption = post['caption']?.toString() ?? '';
    final countMap = post['_count'] as Map<String, dynamic>? ?? {};
    final media = post['media'] as List? ?? [];
    final firstMedia = media.isNotEmpty
        ? (media.first['media'] as Map<String, dynamic>?)
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (firstMedia != null && firstMedia['url'] != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                firstMedia['url'].toString(),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(caption,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF1A1A2E))),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              children: [
                _PostStat(Icons.favorite_outline,
                    (countMap['likes'] ?? 0).toString()),
                const SizedBox(width: 14),
                _PostStat(Icons.comment_outlined,
                    (countMap['comments'] ?? 0).toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostStat extends StatelessWidget {
  final IconData icon;
  final String count;
  const _PostStat(this.icon, this.count);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(count,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

// ── About Section ─────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  final PetModel pet;
  const _AboutSection({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Animal Type', pet.animalTypeName),
            _row('Breed', pet.breedName),
            _row('Sex', pet.sex),
            _row('Color', pet.colorName),
            _row('Size', pet.sizeName),
            _row('Date of Birth',
                pet.dateOfBirth?.toIso8601String().split('T').first),
            if (pet.isRescue == true) _row('Rescue Pet', 'Yes'),
            _row('Food Habits', pet.foodHabits),
            _row('Notes', pet.notes),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style:
                    TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Health Section ────────────────────────────────────────────────────────────

class _HealthSection extends StatelessWidget {
  final PetModel pet;
  const _HealthSection({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Neutered/Spayed', pet.isNeutered == true ? 'Yes' : 'No'),
            _row('Microchip Number', pet.microchipNumber),
            _row('Blood Type', pet.bloodType),
            _row('Health Disorders', pet.healthDisorders),
            if (pet.allergies != null && pet.allergies!.isNotEmpty)
              _row('Allergies', pet.allergies!.join(', ')),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style:
                    TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
