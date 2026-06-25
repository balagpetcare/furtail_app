import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/typography.dart';
import '../../../pets/data/models/pet_model.dart';

class MyPetsFamilyWhite extends StatelessWidget {
  final List<PetModel> pets;
  final ValueChanged<PetModel> onTapPet;
  final VoidCallback onAddNew;

  const MyPetsFamilyWhite({
    super.key,
    required this.pets,
    required this.onTapPet,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE6E6E6)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'My Pets Family',
                style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onAddNew,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (pets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Icon(Icons.pets_rounded, size: 40, color: Colors.black12),
                  const SizedBox(height: 8),
                  const Text(
                    'No pets yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add your first pet to get started!',
                    style: TextStyle(color: Colors.black38, fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: onAddNew,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Pet'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final pet = pets[i];
                  return InkWell(
                    onTap: () => onTapPet(pet),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 140,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFFF6F8FC),
                        border: Border.all(color: const Color(0x11000000)),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFFEFEFEF),
                            backgroundImage: (pet.photoUrl ?? '').trim().isEmpty
                                ? null
                                : NetworkImage(pet.photoUrl!),
                            child: (pet.photoUrl ?? '').trim().isEmpty
                                ? const Icon(Icons.pets, color: Colors.black45)
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pet.name.isEmpty ? 'Pet' : pet.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (pet.breedName ?? '').isEmpty
                                ? 'Tap to view'
                                : pet.breedName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.appText.bodySmall!.copyWith(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
