import 'package:flutter/material.dart';
import 'pet_create_screen.dart';

class PetListScreen extends StatelessWidget {
  const PetListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Pets")),
      floatingActionButton: FloatingActionButton(
        heroTag: 'pets_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PetCreateScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: const Center(
        child: Text("Bind pets list later using GetPetsUsecase"),
      ),
    );
  }
}
