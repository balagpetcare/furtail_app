import 'dart:ui';
import 'package:furtail_app/core/media/furtail_cache_manager.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../pets/data/models/pet_model.dart';

class PetHorizontalList extends StatelessWidget {
  final List<PetModel> pets;
  final VoidCallback? onSeeAll;
  final VoidCallback? onAddNew;
  final void Function(PetModel pet)? onTapPet;

  const PetHorizontalList({
    super.key,
    required this.pets,
    this.onSeeAll,
    this.onAddNew,
    this.onTapPet,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "My Pet Family",
                    style: context.appText.bodyLarge!.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  if (onSeeAll != null)
                    _ActionText(text: "See All", onTap: onSeeAll),
                  const SizedBox(width: 10),
                  _ActionText(text: "Add New +", onTap: onAddNew),
                ],
              ),
              const SizedBox(height: 12),

              if (pets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pets, color: Color(0xFFFFD700)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "No pets added yet. Tap 'Add New +' to create your first pet.",
                          style: context.appText.labelLarge!.copyWith(color: Colors.white.withValues(alpha: 0.78), fontWeight: FontWeight.w600, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 170,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pets.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final pet = pets[index];
                      final imageUrl = (pet.photoUrl ?? "").toString().trim();
                      final petName = pet.name.toString().trim().isEmpty
                          ? "Pet"
                          : pet.name.toString();
                      final subtitle =
                          (pet.breedName ?? pet.animalTypeName ?? "")
                              .toString();

                      return InkWell(
                        onTap: onTapPet == null ? null : () => onTapPet!(pet),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: imageUrl.isEmpty
                                      ? _fallback()
                                      : CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          cacheManager: FurtailImageCacheManager(),
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder: (_, _) => _loading(context),
                                          errorWidget: (_, _, _) =>
                                              _fallback(),
                                        ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      petName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.appText.labelLarge!.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.appText.labelMedium!.copyWith(color: Colors.white.withValues(alpha: 0.65), fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
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
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: Colors.white.withValues(alpha: 0.06),
      child: Center(
        child: Icon(
          Icons.pets,
          size: 28,
          color: Colors.white.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  Widget _loading(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.06),
      child: Center(
        child: Text(
          "Loading pet joy...",
          style: context.appText.labelMedium!.copyWith(color: Colors.white.withValues(alpha: 0.65)),
        ),
      ),
    );
  }
}

class _ActionText extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _ActionText({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
