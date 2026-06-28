import 'package:flutter/material.dart';

import 'package:furtail_app/core/widgets/social_action_row.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_media_models.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';

enum AdoptionCardMenuAction {
  editListing,
  updateStatus,
  archiveListing,
  reportListing,
  shareListing,
  saveListing,
}

class AdoptionPetCard extends StatelessWidget {
  final AdoptionPetUiModel pet;
  final VoidCallback onOpenDetails;
  final VoidCallback onToggleFavorite;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback? onSave;
  final VoidCallback? onOwnerTap;
  final bool isFavorited;
  final bool isOwnedByMe;
  final bool canEdit;
  final ValueChanged<AdoptionCardMenuAction>? onMenuSelected;

  const AdoptionPetCard({
    super.key,
    required this.pet,
    required this.onOpenDetails,
    required this.onToggleFavorite,
    required this.onComment,
    required this.onShare,
    this.onSave,
    this.onOwnerTap,
    required this.isFavorited,
    this.isOwnedByMe = false,
    this.canEdit = false,
    this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    return Material(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: _OwnerHeader(
              pet: pet,
              isOwnedByMe: isOwnedByMe,
              onOwnerTap: onOwnerTap,
              onMenuSelected: onMenuSelected,
            ),
          ),
          InkWell(
            onTap: onOpenDetails,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _AdoptionImage(media: pet.coverMedia, species: pet.species),
                  if (_showStatusBadge)
                    Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: _StatusBadge(status: pet.status),
                    ),
                  if (pet.media.length > 1)
                    Positioned(
                      right: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: _MediaCountBadge(count: pet.media.length),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.menuTitle(
                          context,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (pet.isShelter || pet.ownerRoleLabel.isNotEmpty)
                      _RolePill(
                        label: pet.ownerRoleLabel,
                        isShelter: pet.isShelter,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _breedLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(
                    context,
                  ).copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _MetaPill(icon: Icons.cake_outlined, label: pet.ageLabel),
                    _MetaPill(
                      icon: pet.gender == 'Male'
                          ? Icons.male_rounded
                          : pet.gender == 'Female'
                          ? Icons.female_rounded
                          : Icons.help_outline_rounded,
                      label: pet.gender,
                    ),
                    _MetaPill(icon: Icons.place_outlined, label: pet.location),
                  ],
                ),
                if (pet.vaccinated ||
                    pet.dewormed ||
                    pet.neutered ||
                    pet.microchipped) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (pet.vaccinated)
                        _HealthBadge(label: 'Vaccinated', color: Colors.green),
                      if (pet.dewormed)
                        _HealthBadge(label: 'Dewormed', color: Colors.teal),
                      if (pet.neutered)
                        _HealthBadge(label: 'Neutered', color: Colors.blue),
                      if (pet.microchipped)
                        _HealthBadge(
                          label: 'Microchipped',
                          color: Colors.deepPurple,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: SocialActionRow(
              likeCount: pet.favoriteCount,
              commentCount: pet.commentCount,
              shareCount: 0,
              isLiked: isFavorited,
              onLike: onToggleFavorite,
              onComment: onComment,
              onShare: onShare,
              showSaveButton: true,
              isSaved: isFavorited,
              onSave: onSave ?? onToggleFavorite,
            ),
          ),
        ],
      ),
    );
  }

  bool get _showStatusBadge {
    final status = pet.status;
    return status != 'Available' &&
        status != 'Published' &&
        status != 'Approved';
  }

  String get _breedLine {
    final breed = pet.breed.trim();
    if (breed.isEmpty || breed == 'Breed not specified') {
      return pet.species;
    }
    return '${pet.species} · $breed';
  }

}

class AdoptionPetCardSkeleton extends StatelessWidget {
  const AdoptionPetCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Material(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: const [
                _SkeletonAvatar(),
                SizedBox(width: 10),
                Expanded(child: _SkeletonHeader()),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(widthFactor: 0.42),
                const SizedBox(height: 8),
                _SkeletonLine(widthFactor: 0.74, height: 10),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: const [
                    _SkeletonPill(width: 78),
                    _SkeletonPill(width: 66),
                    _SkeletonPill(width: 104),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Expanded(child: _SkeletonAction()),
                Expanded(child: _SkeletonAction()),
                Expanded(child: _SkeletonAction()),
                Expanded(child: _SkeletonAction()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerHeader extends StatelessWidget {
  final AdoptionPetUiModel pet;
  final bool isOwnedByMe;
  final VoidCallback? onOwnerTap;
  final ValueChanged<AdoptionCardMenuAction>? onMenuSelected;

  const _OwnerHeader({
    required this.pet,
    required this.isOwnedByMe,
    required this.onOwnerTap,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (pet.ownerRoleLabel.isNotEmpty) pet.ownerRoleLabel,
      if (pet.location.trim().isNotEmpty) pet.location.trim(),
      if (_showStatusMeta) pet.status,
    ].join(' · ');

    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onOwnerTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  FurtailNetworkAvatar(
                    imageUrl: pet.ownerAvatarUrl,
                    displayName: pet.ownerName,
                    radius: 20,
                    badge: pet.ownerVerified
                        ? Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified,
                              size: 12,
                              color: Colors.blue,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pet.ownerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.menuTitle(
                            context,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (meta.isNotEmpty)
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption(context).copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onMenuSelected != null)
          PopupMenuButton<AdoptionCardMenuAction>(
            tooltip: 'More actions',
            onSelected: onMenuSelected,
            itemBuilder: (context) {
              if (isOwnedByMe) {
                return const [
                  PopupMenuItem(
                    value: AdoptionCardMenuAction.editListing,
                    child: Text('Edit listing'),
                  ),
                  PopupMenuItem(
                    value: AdoptionCardMenuAction.updateStatus,
                    child: Text('View applications'),
                  ),
                  PopupMenuItem(
                    value: AdoptionCardMenuAction.shareListing,
                    child: Text('Share'),
                  ),
                ];
              }
              return const [
                PopupMenuItem(
                  value: AdoptionCardMenuAction.shareListing,
                  child: Text('Share'),
                ),
                PopupMenuItem(
                  value: AdoptionCardMenuAction.saveListing,
                  child: Text('Save'),
                ),
                PopupMenuItem(
                  value: AdoptionCardMenuAction.reportListing,
                  child: Text('Report listing'),
                ),
              ];
            },
            icon: const Icon(Icons.more_horiz),
          ),
      ],
    );
  }

  bool get _showStatusMeta {
    final status = pet.status;
    return status != 'Available' &&
        status != 'Published' &&
        status != 'Approved';
  }
}

class _MediaCountBadge extends StatelessWidget {
  final int count;

  const _MediaCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 10,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdoptionImage extends StatelessWidget {
  final AdoptionMediaUiModel? media;
  final String species;

  const _AdoptionImage({required this.media, required this.species});

  @override
  Widget build(BuildContext context) {
    final item = media;
    if (item == null) {
      return _FallbackArt(species: species);
    }

    if (item.isVideo && (item.thumbnailUrl ?? '').trim().isEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _FallbackArt(species: species),
          Container(
            color: Colors.black.withValues(alpha: 0.18),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 48,
                shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
              ),
            ),
          ),
        ],
      );
    }

    final url = item.previewImageUrl ?? '';
    if (url.trim().isEmpty) {
      return _FallbackArt(species: species);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FurtailCachedImage(imageUrl: url, fit: BoxFit.cover),
        if (item.isVideo)
          Container(
            color: Colors.black.withValues(alpha: 0.15),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 48,
                shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
              ),
            ),
          ),
      ],
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
            cs.primary.withValues(alpha: 0.12),
            cs.secondary.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _iconForSpecies(species),
          size: 42,
          color: cs.primary.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  IconData _iconForSpecies(String value) => switch (value) {
    'Cats' => Icons.pets_rounded,
    'Dogs' => Icons.cruelty_free_outlined,
    'Birds' => Icons.flutter_dash_rounded,
    'Rabbits' => Icons.emoji_nature_rounded,
    _ => Icons.favorite_border_rounded,
  };
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      'Draft' => (Colors.grey.shade800, Colors.grey.shade100),
      'Pending Review' => (Colors.orange.shade800, Colors.orange.shade50),
      'Adopted' => (Colors.blueGrey.shade700, Colors.blueGrey.shade50),
      'Paused' => (Colors.blueGrey.shade700, Colors.blueGrey.shade50),
      'Needs changes' => (
        Colors.deepOrange.shade700,
        Colors.deepOrange.shade50,
      ),
      'Rejected' => (Colors.red.shade700, Colors.red.shade50),
      'Applications Closed' => (Colors.grey.shade800, Colors.grey.shade100),
      'Reported' => (Colors.red.shade700, Colors.red.shade50),
      _ => (Colors.green.shade700, Colors.green.shade50),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String label;
  final bool isShelter;

  const _RolePill({required this.label, required this.isShelter});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final color = isShelter ? cs.secondary : cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.28,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(context).copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _HealthBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color.withValues(alpha: 0.9),
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _FeedActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FeedActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final color = selected ? cs.primary : cs.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.caption(
                context,
              ).copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonAvatar extends StatelessWidget {
  const _SkeletonAvatar();

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SkeletonHeader extends StatelessWidget {
  const _SkeletonHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonLine(widthFactor: 0.42),
        SizedBox(height: 6),
        _SkeletonLine(widthFactor: 0.68, height: 10),
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;
  final double height;

  const _SkeletonLine({required this.widthFactor, this.height = 12});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  final double width;

  const _SkeletonPill({required this.width});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      width: width,
      height: 22,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _SkeletonAction extends StatelessWidget {
  const _SkeletonAction();

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
