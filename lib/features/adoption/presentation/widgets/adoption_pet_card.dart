import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';

class AdoptionPetCard extends StatelessWidget {
  final AdoptionPetUiModel pet;
  final VoidCallback onTap;
  final bool isSaved;
  final VoidCallback onToggleSaved;

  const AdoptionPetCard({
    super.key,
    required this.pet,
    required this.onTap,
    required this.isSaved,
    required this.onToggleSaved,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                children: [
                  if ((pet.coverImageUrl ?? '').isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        pet.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _FallbackArt(species: pet.species),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return _FallbackArt(species: pet.species);
                        },
                      ),
                    )
                  else
                    Positioned.fill(
                      child: _FallbackArt(species: pet.species),
                    ),
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    child: _StatusBadge(status: pet.status),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: IconButton.filledTonal(
                      onPressed: onToggleSaved,
                      icon: Icon(
                        isSaved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.menuTitle(context).copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _OwnerBadge(
                        label: pet.ownerRoleLabel,
                        isShelter: pet.isShelter,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${pet.species} • ${pet.breed}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyRegular(
                      context,
                    ).copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${pet.ageLabel} • ${pet.gender}',
                    style: AppTypography.caption(
                      context,
                    ).copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          pet.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(
                            context,
                          ).copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (pet.vaccinated)
                        const _HealthBadge(label: 'Vaccinated'),
                      if (pet.dewormed) const _HealthBadge(label: 'Dewormed'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _FallbackArt extends StatelessWidget {
  final String species;

  const _FallbackArt({required this.species});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.18),
            cs.secondary.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _speciesIconFor(species),
          size: 44,
          color: cs.primary,
        ),
      ),
    );
  }

  IconData _speciesIconFor(String species) {
    switch (species) {
      case 'Cats':
        return Icons.pets_rounded;
      case 'Dogs':
        return Icons.cruelty_free_outlined;
      case 'Birds':
        return Icons.flutter_dash_rounded;
      case 'Rabbits':
        return Icons.emoji_nature_rounded;
      default:
        return Icons.favorite_border_rounded;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final Color color = switch (status) {
      'Draft' => cs.primary,
      'Published' => Colors.green,
      'Pending Review' => Colors.orange,
      'Available' => Colors.green,
      'Pending' => Colors.orange,
      'Adopted' => cs.onSurfaceVariant,
      'Needs changes' => Colors.deepOrange,
      'Rejected' => Colors.red,
      'Paused' => cs.onSurfaceVariant,
      _ => cs.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: AppTypography.meta(
          context,
        ).copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OwnerBadge extends StatelessWidget {
  final String label;
  final bool isShelter;

  const _OwnerBadge({required this.label, required this.isShelter});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: (isShelter ? cs.secondary : cs.primary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.meta(context).copyWith(
          color: isShelter ? cs.secondary : cs.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  final String label;

  const _HealthBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.meta(
          context,
        ).copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
      ),
    );
  }
}
