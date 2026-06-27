import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/adoption/presentation/screens/adoption_apply_screen.dart';

class AdoptionPetDetailScreen extends StatefulWidget {
  final AdoptionPetUiModel pet;
  final AdoptionRepository repository;
  final bool isSaved;
  final VoidCallback onToggleSaved;

  const AdoptionPetDetailScreen({
    super.key,
    required this.pet,
    required this.repository,
    required this.isSaved,
    required this.onToggleSaved,
  });

  @override
  State<AdoptionPetDetailScreen> createState() => _AdoptionPetDetailScreenState();
}

class _AdoptionPetDetailScreenState extends State<AdoptionPetDetailScreen> {
  late AdoptionPetUiModel _pet;
  bool _loadingDetail = true;

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await widget.repository.fetchAdoptionDetail(widget.pet.id);
      if (!mounted) return;
      setState(() {
        _pet = detail;
        _loadingDetail = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDetail = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load full adoption detail. Showing summary data.'),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final pet = _pet;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adoption Details'),
        actions: [
          IconButton(
            onPressed: widget.onToggleSaved,
            icon: Icon(
              widget.isSaved
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: pet.galleryLabels.length,
                  itemBuilder: (context, index) {
                    final imageUrl = index < pet.galleryImageUrls.length
                        ? pet.galleryImageUrls[index]
                        : null;
                    return Container(
                      margin: EdgeInsets.fromLTRB(
                        index == 0 ? AppSpacing.lg : AppSpacing.sm,
                        AppSpacing.md,
                        index == pet.galleryLabels.length - 1
                            ? AppSpacing.lg
                            : AppSpacing.sm,
                        AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            cs.primary.withValues(alpha: 0.18),
                            cs.secondary.withValues(alpha: 0.12),
                          ],
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _GalleryPlaceholder(label: pet.galleryLabels[index]),
                              )
                            : _GalleryPlaceholder(label: pet.galleryLabels[index]),
                      ),
                    );
                  },
                ),
                if (_loadingDetail)
                  const Positioned(
                    top: 16,
                    right: 20,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  style: AppTypography.pageTitle(
                    context,
                  ).copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${pet.species} • ${pet.breed} • ${pet.ageLabel} • ${pet.gender}',
                  style: AppTypography.bodyRegular(
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
                        style: AppTypography.caption(
                          context,
                        ).copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'Pet Story',
                  child: Text(
                    pet.story,
                    style: AppTypography.bodyRegular(
                      context,
                    ).copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'Health Information',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.healthNotes,
                        style: AppTypography.bodyRegular(
                          context,
                        ).copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _InfoChip(
                            label: pet.vaccinated
                                ? 'Vaccinated'
                                : 'Not vaccinated',
                          ),
                          _InfoChip(
                            label: pet.dewormed
                                ? 'Dewormed'
                                : 'No deworming record',
                          ),
                          _InfoChip(
                            label: pet.neutered ? 'Neutered' : 'Not neutered',
                          ),
                          _InfoChip(
                            label: pet.microchipped
                                ? 'Microchipped'
                                : 'No microchip',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'Personality & Compatibility',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: pet.personalityTags
                            .map((tag) => _InfoChip(label: tag))
                            .toList(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: pet.compatibilityTags
                            .map((tag) => _InfoChip(label: tag))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'Adoption Service Areas',
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: pet.serviceAreas
                        .map((area) => _InfoChip(label: area))
                        .toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'Owner / Shelter Summary',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.ownerName,
                        style: AppTypography.menuTitle(
                          context,
                        ).copyWith(color: cs.onSurface),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        pet.ownerRoleLabel,
                        style: AppTypography.caption(
                          context,
                        ).copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        pet.description,
                        style: AppTypography.bodyRegular(
                          context,
                        ).copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'Adopter Conditions',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: pet.adopterConditions
                        .map(
                          (condition) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 18,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    condition,
                                    style: AppTypography.bodyRegular(
                                      context,
                                    ).copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdoptionApplyScreen(
                        pet: pet,
                        repository: widget.repository,
                      ),
                    ),
                  ),
                  child: const Text('Apply to Adopt'),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () => _showActionSnackBar(
                    context,
                    'Owner messaging will be added in a future update.',
                  ),
                  child: const Text('Message Owner'),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onToggleSaved,
                        icon: Icon(
                          widget.isSaved
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                        ),
                        label: const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showActionSnackBar(
                          context,
                          'Share support will be connected later.',
                        ),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => _showActionSnackBar(
                    context,
                    'Reporting for adoption listings will be added later.',
                  ),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Report'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _showActionSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _GalleryPlaceholder extends StatelessWidget {
  final String label;

  const _GalleryPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.photo_library_rounded,
          size: 42,
          color: cs.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          label,
          style: AppTypography.menuTitle(
            context,
          ).copyWith(color: cs.onSurface),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Media carousel placeholder',
          style: AppTypography.caption(
            context,
          ).copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.menuTitle(
              context,
            ).copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        label,
        style: AppTypography.caption(
          context,
        ).copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
      ),
    );
  }
}
