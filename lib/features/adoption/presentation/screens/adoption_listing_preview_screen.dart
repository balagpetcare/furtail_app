import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_media_models.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_listing_form_payload.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:video_player/video_player.dart';

const _speciesLabels = <String, String>{
  'CAT': 'Cat',
  'DOG': 'Dog',
  'BIRD': 'Bird',
  'RABBIT': 'Rabbit',
  'OTHER': 'Other',
};

const _genderLabels = <String, String>{
  'UNKNOWN': 'Not specified',
  'MALE': 'Male',
  'FEMALE': 'Female',
};

const _serviceAreaLabels = <String, String>{
  'SAME_AREA': 'Same area',
  'SAME_CITY': 'Same city',
  'SAME_DISTRICT': 'Same district',
  'SAME_DIVISION': 'Same division',
  'ANYWHERE_COUNTRY': 'Anywhere in country',
  'CUSTOM_AREAS': 'Custom areas',
  'RADIUS_BASED': 'Radius based',
  'INTERNATIONAL': 'International',
};

class AdoptionListingPreviewScreen extends StatefulWidget {
  final AdoptionListingFormPayload payload;
  final AdoptionRepository repository;
  final List<AdoptionDraftMediaItem> localMedia;
  final int? existingListingId;

  const AdoptionListingPreviewScreen({
    super.key,
    required this.payload,
    required this.repository,
    required this.localMedia,
    this.existingListingId,
  });

  @override
  State<AdoptionListingPreviewScreen> createState() =>
      _AdoptionListingPreviewScreenState();
}

class _AdoptionListingPreviewScreenState
    extends State<AdoptionListingPreviewScreen> {
  bool _publishing = false;
  int _photoPage = 0;
  final _photoPageCtrl = PageController();

  @override
  void dispose() {
    _photoPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_publishing) return;
    setState(() => _publishing = true);
    try {
      if (widget.existingListingId != null) {
        await widget.repository.updateAdoptionListing(
          widget.existingListingId!,
          widget.payload,
          submitNow: true,
        );
      } else {
        await widget.repository
            .createAdoptionListing(widget.payload, submitNow: true);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingListingId != null
              ? 'Your adoption listing has been updated.'
              : 'Your adoption listing is now public.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (widget.existingListingId != null) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isEmpty ? 'Could not publish. Please try again.' : msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final p = widget.payload;
    final name = p.name.isEmpty ? 'Unnamed pet' : p.name;
    final species = _speciesLabels[p.species] ?? p.species;
    final breed = p.breed.trim();
    final gender = _genderLabels[p.gender] ?? p.gender;
    final serviceArea = _serviceAreaLabels[p.serviceAreaType] ?? p.serviceAreaType;
    final hasMedia = widget.localMedia.isNotEmpty;
    final adoptionConditions = _buildConditions(p);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Listing'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: FilledButton.icon(
              onPressed: _publishing ? null : _publish,
              icon: _publishing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.rocket_launch_rounded, size: 15),
              label: const Text('Publish Now'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photos / video hero
            if (hasMedia)
              _MediaCarousel(
                items: widget.localMedia,
                controller: _photoPageCtrl,
                pageIndex: _photoPage,
                onPageChanged: (i) => setState(() => _photoPage = i),
              )
            else
              _EmptyPhotoHero(cs: cs),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    name,
                    style: AppTypography.sectionTitle(context)
                        .copyWith(fontWeight: FontWeight.w800, fontSize: 22),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Species / breed / gender / age badges
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Badge(species, cs.primaryContainer,
                          cs.onPrimaryContainer),
                      if (breed.isNotEmpty)
                        _Badge(breed, cs.secondaryContainer,
                            cs.onSecondaryContainer),
                      if (gender != 'Not specified')
                        _Badge(gender, cs.surfaceContainerHighest, cs.onSurface),
                      if (p.ageText.trim().isNotEmpty)
                        _Badge(p.ageText.trim(), cs.surfaceContainerHighest,
                            cs.onSurface),
                      if (p.sizeText.trim().isNotEmpty)
                        _Badge(p.sizeText.trim(), cs.surfaceContainerHighest,
                            cs.onSurface),
                      if (p.colorText.trim().isNotEmpty)
                        _Badge(p.colorText.trim(), cs.surfaceContainerHighest,
                            cs.onSurface),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Health badges
                  if (p.vaccinated || p.dewormed || p.neutered || p.microchipped)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (p.vaccinated)
                          _Badge('Vaccinated', Colors.green.shade50,
                              Colors.green.shade700),
                        if (p.dewormed)
                          _Badge('Dewormed', Colors.green.shade50,
                              Colors.green.shade700),
                        if (p.neutered)
                          _Badge('Neutered/Spayed', Colors.teal.shade50,
                              Colors.teal.shade700),
                        if (p.microchipped)
                          _Badge('Microchipped', Colors.blue.shade50,
                              Colors.blue.shade700),
                      ],
                    ),

                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.md),

                  // Location
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: _buildLocation(p),
                    cs: cs,
                  ),
                  if (p.latitude != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _InfoRow(
                      icon: Icons.my_location_rounded,
                      label: 'GPS',
                      value:
                          '${p.latitude!.toStringAsFixed(5)}, ${p.longitude!.toStringAsFixed(5)}',
                      cs: cs,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  _InfoRow(
                    icon: Icons.map_outlined,
                    label: 'Service area',
                    value: serviceArea,
                    cs: cs,
                  ),
                  if (p.allowInternationalAdoption) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _InfoRow(
                      icon: Icons.public,
                      label: 'International',
                      value: 'International adoption allowed',
                      cs: cs,
                    ),
                  ],
                  if (p.serviceAreaNotes.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _InfoRow(
                      icon: Icons.notes_outlined,
                      label: 'Area notes',
                      value: p.serviceAreaNotes.trim(),
                      cs: cs,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.md),

                  // Story
                  if (p.description.trim().isNotEmpty) ...[
                    _sectionHeading('Story', context),
                    const SizedBox(height: 4),
                    Text(p.description.trim(),
                        style: AppTypography.bodyRegular(context)
                            .copyWith(color: cs.onSurfaceVariant, height: 1.5)),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Adoption reason
                  if (p.adoptionReason.trim().isNotEmpty) ...[
                    _sectionHeading('Reason for rehoming', context),
                    const SizedBox(height: 4),
                    Text(p.adoptionReason.trim(),
                        style: AppTypography.bodyRegular(context)
                            .copyWith(color: cs.onSurfaceVariant, height: 1.5)),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Health notes
                  if (p.healthInfo.trim().isNotEmpty) ...[
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.md),
                    _sectionHeading('Health notes', context),
                    const SizedBox(height: 4),
                    Text(p.healthInfo.trim(),
                        style: AppTypography.bodyRegular(context)
                            .copyWith(color: cs.onSurfaceVariant, height: 1.5)),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Adopter conditions
                  if (adoptionConditions.isNotEmpty) ...[
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.md),
                    _sectionHeading('Adopter requirements', context),
                    const SizedBox(height: 8),
                    ...adoptionConditions.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 14, color: cs.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(c,
                                  style: AppTypography.bodyRegular(context)
                                      .copyWith(color: cs.onSurface)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.md),

                  // Preview disclaimer
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: cs.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 14, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'This is how your listing will look to adopters. Tap "Publish Now" to make it public.',
                            style: AppTypography.caption(context).copyWith(
                                color: cs.onPrimaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Publish button (duplicate from AppBar for convenience)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _publishing ? null : _publish,
                      icon: _publishing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.rocket_launch_rounded, size: 16),
                      label: const Text('Publish Now'),
                      style: FilledButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit listing'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildLocation(AdoptionListingFormPayload p) {
    return 'Bangladesh';
  }

  List<String> _buildConditions(AdoptionListingFormPayload p) {
    return [
      if (p.previousPetExperienceRequired) 'Previous pet experience required',
      if (p.familyApprovalRequired) 'Family approval required',
      if (p.canProvideVetCare) 'Must be able to provide regular vet care',
      if (p.noResaleAgreement) 'No resale or abandonment agreement',
      if (p.followUpAgreement) 'Post-adoption follow-up agreement',
      if (p.minimumIncomeRange.trim().isNotEmpty)
        'Minimum income: ${p.minimumIncomeRange.trim()}',
      if (p.maximumIncomeRange.trim().isNotEmpty)
        'Maximum income: ${p.maximumIncomeRange.trim()}',
      if (p.adopterConditionNote.trim().isNotEmpty) p.adopterConditionNote.trim(),
    ];
  }
}

// ─────────────────────────────── Widgets ─────────────────────────────────────

class _MediaCarousel extends StatelessWidget {
  final List<AdoptionDraftMediaItem> items;
  final PageController controller;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;

  const _MediaCarousel({
    required this.items,
    required this.controller,
    required this.pageIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: items.length,
            onPageChanged: onPageChanged,
            itemBuilder: (_, i) {
              final item = items[i];
              if (item.isVideo) {
                return _PreviewVideoHero(item: item);
              }
              return Image.file(
                item.file,
                fit: BoxFit.cover,
                width: double.infinity,
              );
            },
          ),
          if (items.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  items.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == pageIndex ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == pageIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          if (items.length > 1)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${pageIndex + 1} / ${items.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewVideoHero extends StatefulWidget {
  final AdoptionDraftMediaItem item;

  const _PreviewVideoHero({required this.item});

  @override
  State<_PreviewVideoHero> createState() => _PreviewVideoHeroState();
}

class _PreviewVideoHeroState extends State<_PreviewVideoHero> {
  VideoPlayerController? _controller;
  Future<void>? _init;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final token = ++_token;
    final controller = VideoPlayerController.file(widget.item.file);
    _controller = controller;
    _init = controller.initialize().then((_) {
      if (!mounted || token != _token) return;
      controller.setLooping(true);
      controller.pause();
      setState(() {});
    }).catchError((_) {});
  }

  @override
  void didUpdateWidget(covariant _PreviewVideoHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.file.path != widget.item.file.path) {
      final controller = _controller;
      _controller = null;
      _init = null;
      try {
        controller?.pause();
      } catch (_) {}
      controller?.dispose();
      _initController();
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    try {
      controller?.pause();
    } catch (_) {}
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || _init == null) {
      return const ColoredBox(color: Colors.black87);
    }

    return FutureBuilder<void>(
      future: _init,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (widget.item.thumbnail != null)
                Image.file(widget.item.thumbnail!, fit: BoxFit.cover)
              else
                const ColoredBox(color: Colors.black87),
              Container(color: Colors.black.withValues(alpha: 0.18)),
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 72,
                ),
              ),
            ],
          );
        }
        return GestureDetector(
          onTap: () {
            if (controller.value.isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
            setState(() {});
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
              if (!controller.value.isPlaying)
                Container(
                  color: Colors.black.withValues(alpha: 0.2),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 72,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyPhotoHero extends StatelessWidget {
  final ColorScheme cs;
  const _EmptyPhotoHero({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      color: cs.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 36, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(
            'No media',
            style: AppTypography.caption(context)
                .copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text('$label: ',
            style: AppTypography.caption(context).copyWith(
                color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(value,
              style: AppTypography.caption(context)
                  .copyWith(color: cs.onSurfaceVariant)),
        ),
      ],
    );
  }
}

Widget _sectionHeading(String text, BuildContext context) {
  return Text(text,
      style: AppTypography.menuTitle(context)
          .copyWith(fontWeight: FontWeight.w700));
}
