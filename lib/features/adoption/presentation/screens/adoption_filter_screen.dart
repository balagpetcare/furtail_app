import 'package:flutter/material.dart';
import 'package:furtail_app/core/widgets/placeholder_screen.dart';

class AdoptionFilterScreen extends StatelessWidget {
  const AdoptionFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Adoption Filters',
      message:
          'Filter controls are being prepared for the next adoption update.',
      icon: Icons.tune_rounded,
    );
  }
}
