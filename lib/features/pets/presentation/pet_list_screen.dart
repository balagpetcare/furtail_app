import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/pet_entity.dart';
import 'pet_profile_wizard_screen.dart';
import 'providers/pet_providers.dart';
import 'screens/pet_profile_screen.dart';

class PetListScreen extends ConsumerWidget {
  const PetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsState = ref.watch(ownerPetListProvider);
    final pets = petsState.pets;

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
            fontSize: 18,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'pets_fab',
        backgroundColor: const Color(0xFF4C6EF5),
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const PetProfileWizardScreen()),
          );
          if (result == true) {
            await ref.read(ownerPetListProvider.notifier).refresh();
          }
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Pet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: petsState.initialLoading && !petsState.hasLoadedOnce
          ? const Center(child: CircularProgressIndicator())
          : petsState.error != null && pets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    petsState.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(ownerPetListProvider.notifier).refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                pets.isEmpty
                    ? _EmptyPets(
                        onAdd: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PetProfileWizardScreen(),
                            ),
                          );
                          if (result == true) {
                            await ref
                                .read(ownerPetListProvider.notifier)
                                .refresh();
                          }
                        },
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(ownerPetListProvider.notifier).refresh(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: pets.length,
                          itemBuilder: (ctx, i) => _PetCard(
                            pet: pets[i],
                            onTap: () async {
                              final petId = pets[i].id;
                              if (petId == null) return;
                              final result = await Navigator.push<bool>(
                                ctx,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PetProfileScreen(petId: petId),
                                ),
                              );
                              if (result == true) {
                                await ref
                                    .read(ownerPetListProvider.notifier)
                                    .refresh();
                              }
                            },
                            onEdit: () async {
                              final petId = pets[i].id;
                              if (petId == null) return;
                              final result = await Navigator.push<bool>(
                                ctx,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PetProfileWizardScreen(petId: petId),
                                ),
                              );
                              if (result == true) {
                                await ref
                                    .read(ownerPetListProvider.notifier)
                                    .refresh();
                              }
                            },
                          ),
                        ),
                      ),
                if (petsState.refreshing)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
    );
  }
}

class _PetCard extends StatelessWidget {
  final PetEntity pet;
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
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                        if (pet.isPublicProfileEnabled == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF4C6EF5,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Public',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF4C6EF5),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        pet.animalTypeName,
                        pet.breedName,
                      ].where((s) => s != null && s.isNotEmpty).join(' · '),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    if (pet.sex != null && pet.sex != 'UNKNOWN')
                      Text(
                        _sexLabel(pet.sex!),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    if (pet.isPublicProfileEnabled == true) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _MiniStat(
                            Icons.people_outline,
                            pet.followersCount ?? 0,
                            'followers',
                          ),
                          const SizedBox(width: 12),
                          _MiniStat(
                            Icons.favorite_outline,
                            pet.likesCount ?? 0,
                            'likes',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF4C6EF5),
                  size: 20,
                ),
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
        return 'Male';
      case 'FEMALE':
        return 'Female';
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
    final normalizedUrl = photoUrl?.trim();
    return CircleAvatar(
      radius: 34,
      backgroundColor: const Color(0xFF4C6EF5).withValues(alpha: 0.1),
      backgroundImage: normalizedUrl != null && normalizedUrl.isNotEmpty
          ? NetworkImage(normalizedUrl)
          : null,
      child: normalizedUrl == null || normalizedUrl.isEmpty
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
        Text(
          '$count $label',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
      ],
    );
  }
}

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
              child: const Icon(
                Icons.pets_rounded,
                size: 52,
                color: Color(0xFF4C6EF5),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No pets yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first pet profile to manage health, updates, and family details in one place.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Register New Pet'),
            ),
          ],
        ),
      ),
    );
  }
}
