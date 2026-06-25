import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pet_service.dart';
import '../data/models/pet_model.dart';
import 'pet_profile_wizard_screen.dart';
import 'screens/pet_public_profile_screen.dart';

// ── Provider ────────────────────────────────────────────────────────────────

final _myPetsProvider = FutureProvider.autoDispose<List<PetModel>>((ref) {
  return PetService().getMyPets();
});

// ── Screen ───────────────────────────────────────────────────────────────────

class PetListScreen extends ConsumerWidget {
  const PetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsAsync = ref.watch(_myPetsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'My Pets',
          style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontWeight: FontWeight.w800,
              fontSize: 18),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'pets_fab',
        backgroundColor: const Color(0xFF4C6EF5),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PetProfileWizardScreen(),
            ),
          );
          if (result == true) ref.invalidate(_myPetsProvider);
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Pet',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: petsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(_myPetsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (pets) => pets.isEmpty
            ? _EmptyPets(
                onAdd: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PetProfileWizardScreen()),
                  );
                  if (result == true) ref.invalidate(_myPetsProvider);
                },
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(_myPetsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: pets.length,
                  itemBuilder: (ctx, i) => _PetCard(
                    pet: pets[i],
                    onTap: () async {
                      final petId = pets[i].id;
                      if (petId == null) return;
                      final result = await Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) =>
                              PetPublicProfileScreen(petId: petId),
                        ),
                      );
                      if (result == true) ref.invalidate(_myPetsProvider);
                    },
                    onEdit: () async {
                      final petId = pets[i].id;
                      if (petId == null) return;
                      final result = await Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) =>
                              PetProfileWizardScreen(petId: petId),
                        ),
                      );
                      if (result == true) ref.invalidate(_myPetsProvider);
                    },
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Pet Card ─────────────────────────────────────────────────────────────────

class _PetCard extends StatelessWidget {
  final PetModel pet;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _PetCard({
    required this.pet,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _Avatar(photoUrl: pet.photoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pet.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A2E)),
                          ),
                        ),
                        if (pet.isPublicProfileEnabled == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4C6EF5).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Public',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF4C6EF5),
                                    fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [pet.animalTypeName, pet.breedName]
                          .where((s) => s != null && s.isNotEmpty)
                          .join(' · '),
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    if (pet.sex != null && pet.sex != 'UNKNOWN')
                      Text(
                        _sexLabel(pet.sex!),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                    if (pet.isPublicProfileEnabled == true) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _MiniStat(Icons.people_outline,
                              pet.followersCount ?? 0, 'followers'),
                          const SizedBox(width: 12),
                          _MiniStat(Icons.favorite_outline,
                              pet.likesCount ?? 0, 'likes'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Color(0xFF4C6EF5), size: 20),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sexLabel(String sex) {
    switch (sex) {
      case 'MALE':
        return '♂ Male';
      case 'FEMALE':
        return '♀ Female';
      default:
        return '';
    }
  }
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  const _Avatar({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 34,
      backgroundColor: const Color(0xFF4C6EF5).withValues(alpha: 0.1),
      backgroundImage:
          photoUrl != null ? NetworkImage(photoUrl!) : null,
      child: photoUrl == null
          ? const Icon(Icons.pets, size: 28, color: Color(0xFF4C6EF5))
          : null,
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  const _MiniStat(this.icon, this.count, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.grey[500]),
        const SizedBox(width: 3),
        Text('$count $label',
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyPets extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyPets({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF4C6EF5).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets,
                  size: 64, color: Color(0xFF4C6EF5)),
            ),
            const SizedBox(height: 24),
            const Text(
              'No pets yet',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 8),
            Text(
              'Register your pet and create their public profile for others to follow!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4C6EF5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Register First Pet',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
