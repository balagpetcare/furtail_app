import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/typography.dart';
class PostsPlaceholder extends StatelessWidget {
  final VoidCallback onEditProfile;
  const PostsPlaceholder({super.key, required this.onEditProfile});

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
              Text('Posts', style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900)),
              const Spacer(),
              TextButton(
                onPressed: onEditProfile,
                child: const Text('Edit Profile'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x11000000)),
            ),
            child: const Text(
              'TODO: Load and display all posts made by the user (status + media) with pagination/infinite scroll.',
            ),
          ),
        ],
      ),
    );
  }
}
