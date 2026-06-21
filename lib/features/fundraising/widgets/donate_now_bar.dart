import 'package:flutter/material.dart';

// import 'package:furtail_app/core/constants/app_colors.dart';

class DonateNowBar extends StatelessWidget {
  final VoidCallback onDonate;

  const DonateNowBar({super.key, required this.onDonate});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 07, 16, 07),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: onDonate,
            icon: const Icon(Icons.favorite_border),
            label: const Text(
              'Donate Now',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 37, 0, 170),
              foregroundColor: const Color.fromARGB(255, 255, 255, 255),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
