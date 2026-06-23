import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/typography.dart';

import '../../data/models/user_profile_model.dart';
import '../../data/profile_service.dart';

import '../../../pets/presentation/screens/pet_profile_screen.dart';


import '../../../pets/presentation/pet_create_screen.dart';
import '../widgets/profile_header.dart';
import '../widgets/user_stats.dart';
import '../widgets/pet_horizontal_list.dart';
import '../widgets/trophy_case.dart';
import '../widgets/profile_gallery.dart';
import '../widgets/profile_quick_actions.dart';

class ProfileScreen extends StatefulWidget {
  final Future<void> Function()? onPetChanged;

  const ProfileScreen({super.key, this.onPetChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();

  UserProfileModel? profile;

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final p = await _profileService.getProfile();
      if (!mounted) return;
      setState(() {
        profile = p;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceAll("Exception: ", "");
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [SliverToBoxAdapter(child: _buildBody(context))],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 640,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return _errorView(error!);
    }

    final p = profile;
    if (p == null) return _errorView("Profile not found.");

    final pets = p.pets;

    return Column(
      children: [
        ProfileHeader(profile: p),

        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: UserStats(
            followers: p.followers,
            rank: p.rank,
            pawPoints: p.points,
          ),
        ),

        const SizedBox(height: 14),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: TrophyCase(),
        ),

        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PetHorizontalList(
            pets: pets,
            onTapPet: (pet) {
              final id = pet.id;
              if (id == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Pet ID missing. Please refresh."),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PetProfileScreen(petId: id)),
              );
            },
            onSeeAll: () {},
            onAddNew: () async {
              final changed = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PetCreateScreen()),
              );
              if (changed == true) {
                await _load();
                await widget.onPetChanged?.call();
              }
            },
          ),
        ),

        const SizedBox(height: 14),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ProfileQuickActions(),
        ),

        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ProfileGallery(
            urls: p.galleryUrls, // ✅ REQUIRED ARGUMENT
          ),
        ),

        const SizedBox(height: 26),
      ],
    );
  }

  Widget _errorView(String msg) {
    return SizedBox(
      height: 640,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                msg,
                textAlign: TextAlign.center,
                style: AppTypography.bodyRegular(context).copyWith(
                  color: Colors.white.withOpacity(0.80),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text("Retry")),
            ],
          ),
        ),
      ),
    );
  }
}
