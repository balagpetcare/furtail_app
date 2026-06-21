import 'package:flutter/material.dart';
import '../../domain/entities/pet_entity.dart';

class PetCard extends StatelessWidget {
  final PetEntity pet;
  final VoidCallback? onTap;

  const PetCard({super.key, required this.pet, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(child: Icon(Icons.pets)),
        title: Text(pet.name),
        subtitle: Text("Type: ${pet.animalTypeId}, Breed: ${pet.breedId}"),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
