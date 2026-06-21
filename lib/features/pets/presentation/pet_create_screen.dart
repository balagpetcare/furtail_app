import 'package:flutter/material.dart';

import 'pet_profile_wizard_screen.dart';

class PetCreateScreen extends StatelessWidget {
  final int? petId; // null=create, not null=edit
  const PetCreateScreen({super.key, this.petId});

  @override
  Widget build(BuildContext context) {
    return PetProfileWizardScreen(petId: petId);
  }
}
