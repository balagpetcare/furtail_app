import 'package:flutter/material.dart';
import 'package:furtail_app/core/media/feed_video_player.dart';
import 'package:furtail_app/core/navigation/profile_navigation.dart';
import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/core/storage/local_storage.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/core/widgets/social_action_row.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_media_models.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/adoption/presentation/screens/adoption_apply_screen.dart';
import 'package:furtail_app/features/adoption/presentation/screens/listing_applications_screen.dart';
import 'package:furtail_app/features/adoption/presentation/screens/my_adoption_listings_screen.dart';
import 'package:furtail_app/features/adoption/presentation/widgets/adoption_comments_sheet.dart';
import 'package:furtail_app/features/adoption/presentation/widgets/adoption_report_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _DetailMenuAction { edit, applications, share, save, report }

class AdoptionPetDetailScreen extends StatefulWidget {
  final AdoptionPetUiModel pet;
  final AdoptionRepository repository;
  final ValueChanged<AdoptionPetUiModel>? onPetChanged;

  const AdoptionPetDetailScreen({
    super.key,
    required this.pet,
    required this.repository,
    this.onPetChanged,
  });

  @override
  State<AdoptionPetDetailScreen> createState() =>
      _AdoptionPetDetailScreenState();
}

class _AdoptionPetDetailScreenState extends State<AdoptionPetDetailScreen> {
  late AdoptionPetUiModel _pet;
  late bool _isFavorited;
  bool _loadingDetail = true;
  bool _togglingFavorite = false;
  int _carouselPage = 0;
  int? _currentUserId;
  final _carouselCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
    _isFavorited = widget.pet.isFavoritedByMe;
    _loadCurrentUserId();
    _loadDetail();
  }

  @override
  void dispose() {
    _carouselCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await LocalStorage.getUserId();
    if (!mounted) return;
    setState(() => _currentUserId = userId);
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await widget.repository.fetchAdoptionDetail(widget.pet.id);
      if (!mounted) return;
      setState(() {
        _pet = detail;
        _isFavorited = detail.isFavoritedByMe;
        _loadingDetail = false;
      });
      widget.onPetChanged?.call(detail);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDetail = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load full details. Showing summary data.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    if (_loadingDetail || _togglingFavorite || _pet.id <= 0) return;

    final next = !_isFavorited;
    final previous = _pet;
    final optimistic = _pet.copyWith(
      isFavoritedByMe: next,
      favoriteCount: (_pet.favoriteCount + (next ? 1 : -1)).clamp(0, 1 << 30),
    );

    setState(() {
      _isFavorited = next;
      _pet = optimistic;
      _togglingFavorite = true;
    });
    widget.onPetChanged?.call(optimistic);

    try {
      final updated = next
          ? await widget.repository.favoriteAdoption(_pet.id)
          : await widget.repository.unfavoriteAdoption(_pet.id);
      if (!mounted) return;
      setState(() {
        _pet = updated;
        _isFavorited = updated.isFavoritedByMe;
      });
      widget.onPetChanged?.call(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pet = previous;
        _isFavorited = previous.isFavoritedByMe;
      });
      widget.onPetChanged?.call(previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update favorite state.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _togglingFavorite = false);
    }
  }

  Future<void> _openComments() async {
    await showAdoptionCommentsSheet(
      context,
      pet: _pet,
      repository: widget.repository,
      onCountChanged: (count) {
        if (!mounted) return;
        final updated = _pet.copyWith(commentCount: count);
        setState(() => _pet = updated);
        widget.onPetChanged?.call(updated);
      },
    );
  }

  Future<void> _openReport() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('token') ?? '').trim();
    if (!mounted) return;

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to report a listing.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AdoptionReportSheet(
        onSubmit: (reasonCode, details) => widget.repository.reportAdoption(
          _pet.id,
          reasonCode,
          details: details,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks, our team will review this listing.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openOwnerProfile() {
    return ProfileNavigation.openUserProfile(context, _pet.ownerUserId);
  }

  bool get _isOwnedByMe =>
      _pet.viewerIsOwner ||
      (_currentUserId != null && _pet.ownerUserId == _currentUserId);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final pet = _pet;
    final media = pet.media;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: cs.surface,
            surfaceTintColor: Colors.transparent,
            actions: [
              if (_loadingDetail)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              _OverlayIconButton(
                onPressed: _openComments,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                tooltip: 'Comments',
              ),
              _OverlayIconButton(
                onPressed: () => _sharePet(context, pet),
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share',
              ),
              PopupMenuButton<_DetailMenuAction>(
                tooltip: 'More actions',
                onSelected: (value) {
                  switch (value) {
                    case _DetailMenuAction.share:
                      _sharePet(context, pet);
                      break;
                    case _DetailMenuAction.edit:
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MyAdoptionListingsScreen(),
                        ),
                      );
                      break;
                    case _DetailMenuAction.applications:
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ListingApplicationsScreen(
                            adoptionId: pet.id,
                            petName: pet.name,
                          ),
                        ),
                      );
                      break;
                    case _DetailMenuAction.save:
                      _toggleFavorite();
                      break;
                    case _DetailMenuAction.report:
                      _openReport();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (_isOwnedByMe) ...[
                    const PopupMenuItem(
                      value: _DetailMenuAction.edit,
                      child: Text('Edit listing'),
                    ),
                    const PopupMenuItem(
                      value: _DetailMenuAction.applications,
                      child: Text('View applications'),
                    ),
                  ],
                  const PopupMenuItem(
                    value: _DetailMenuAction.share,
                    child: Text('Share'),
                  ),
                  PopupMenuItem(
                    value: _DetailMenuAction.save,
                    child: Text(_isFavorited ? 'Unsave' : 'Save'),
                  ),
                  if (!_isOwnedByMe)
                    const PopupMenuItem(
                      value: _DetailMenuAction.report,
                      child: Text('Report listing'),
                    ),
                ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: _OverlayIconDecoration(
                    child: Icon(Icons.more_horiz_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: media.isNotEmpty
                  ? _MediaCarousel(
                      petId: pet.id,
                      media: media,
                      controller: _carouselCtrl,
                      pageIndex: _carouselPage,
                      onPageChanged: (i) => setState(() => _carouselPage = i),
                    )
                  : _NoPhotoBanner(species: pet.species),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
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
                          style: AppTypography.sectionTitle(
                            context,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _StatusPill(status: pet.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  InkWell(
                    onTap: _openOwnerProfile,
                    borderRadius: BorderRadius.circular(12),
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
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pet.ownerName,
                                  style: AppTypography.menuTitle(
                                    context,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  [
                                    if (pet.ownerRoleLabel.isNotEmpty)
                                      pet.ownerRoleLabel,
                                    if (pet.location.trim().isNotEmpty)
                                      pet.location.trim(),
                                  ].join(' · '),
                                  style: AppTypography.caption(
                                    context,
                                  ).copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _buildSubtitle(pet),
                    style: AppTypography.bodyRegular(
                      context,
                    ).copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _AdoptionSocialActions(
                    pet: pet,
                    isFavorited: _isFavorited,
                    onToggleFavorite: _toggleFavorite,
                    onOpenComments: _openComments,
                    onShare: () => _sharePet(context, pet),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SafetyWarning(),
                  const SizedBox(height: AppSpacing.lg),
                  if (pet.story.isNotEmpty &&
                      pet.story != 'No adoption story shared yet.')
                    _Section(
                      icon: Icons.auto_stories_outlined,
                      title: 'Pet Story',
                      child: Text(
                        pet.story,
                        style: AppTypography.bodyRegular(
                          context,
                        ).copyWith(color: cs.onSurfaceVariant, height: 1.5),
                      ),
                    ),
                  _Section(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Health',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            _HealthChip(
                              label: pet.vaccinated
                                  ? 'Vaccinated'
                                  : 'Not vaccinated',
                              positive: pet.vaccinated,
                            ),
                            _HealthChip(
                              label: pet.dewormed
                                  ? 'Dewormed'
                                  : 'No deworming record',
                              positive: pet.dewormed,
                            ),
                            _HealthChip(
                              label: pet.neutered
                                  ? 'Neutered/Spayed'
                                  : 'Not neutered',
                              positive: pet.neutered,
                            ),
                            _HealthChip(
                              label: pet.microchipped
                                  ? 'Microchipped'
                                  : 'No microchip',
                              positive: pet.microchipped,
                            ),
                          ],
                        ),
                        if (pet.healthNotes.isNotEmpty &&
                            pet.healthNotes !=
                                'No health notes available yet') ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            pet.healthNotes,
                            style: AppTypography.bodyRegular(
                              context,
                            ).copyWith(color: cs.onSurfaceVariant, height: 1.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (pet.personalityTags.isNotEmpty ||
                      pet.compatibilityTags.isNotEmpty)
                    _Section(
                      icon: Icons.psychology_outlined,
                      title: 'Personality & Compatibility',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (pet.personalityTags.isNotEmpty)
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: pet.personalityTags
                                  .map((t) => _InfoChip(label: t))
                                  .toList(),
                            ),
                          if (pet.compatibilityTags.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: pet.compatibilityTags
                                  .map((t) => _InfoChip(label: t))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (pet.serviceAreas.isNotEmpty)
                    _Section(
                      icon: Icons.map_outlined,
                      title: 'Service Areas',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: pet.serviceAreas
                            .map((a) => _InfoChip(label: a))
                            .toList(),
                      ),
                    ),
                  if (pet.adopterConditions.isNotEmpty)
                    _Section(
                      icon: Icons.checklist_rounded,
                      title: 'Adopter Conditions',
                      child: Column(
                        children: pet.adopterConditions
                            .map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 16,
                                      color: cs.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        c,
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
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomActionBar(
        pet: pet,
        repository: widget.repository,
        onReport: _openReport,
        isOwnedByMe: _isOwnedByMe,
      ),
    );
  }

  String _buildSubtitle(AdoptionPetUiModel pet) {
    final parts = <String>[pet.species];
    if (pet.breed != 'Breed not specified') parts.add(pet.breed);
    if (pet.ageLabel != 'Age not specified') parts.add(pet.ageLabel);
    if (pet.gender != 'Unknown') parts.add(pet.gender);
    return parts.join(' · ');
  }

  static void _sharePet(BuildContext context, AdoptionPetUiModel pet) {
    ShareService.share(context, type: 'pet', id: pet.id);
  }
}

class _AdoptionSocialActions extends StatelessWidget {
  final AdoptionPetUiModel pet;
  final bool isFavorited;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenComments;
  final VoidCallback onShare;

  const _AdoptionSocialActions({
    required this.pet,
    required this.isFavorited,
    required this.onToggleFavorite,
    required this.onOpenComments,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return SocialActionRow(
      likeCount: pet.favoriteCount,
      commentCount: pet.commentCount,
      shareCount: 0,
      isLiked: isFavorited,
      onLike: onToggleFavorite,
      onComment: onOpenComments,
      onShare: onShare,
      showSaveButton: true,
      isSaved: isFavorited,
      onSave: onToggleFavorite,
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final AdoptionPetUiModel pet;
  final AdoptionRepository repository;
  final VoidCallback onReport;
  final bool isOwnedByMe;

  const _BottomActionBar({
    required this.pet,
    required this.repository,
    required this.onReport,
    required this.isOwnedByMe,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final canApply =
        pet.status == 'Available' ||
        pet.status == 'Published' ||
        pet.status == 'Approved';
    final canEdit = pet.status == 'Draft' || pet.status == 'Needs changes';

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: isOwnedByMe
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => canEdit
                            ? const MyAdoptionListingsScreen()
                            : ListingApplicationsScreen(
                                adoptionId: pet.id,
                                petName: pet.name,
                              ),
                      ),
                    )
                  : canApply
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdoptionApplyScreen(
                          pet: pet,
                          repository: repository,
                        ),
                      ),
                    )
                  : null,
              icon: Icon(
                isOwnedByMe
                    ? Icons.manage_accounts_outlined
                    : Icons.pets_rounded,
                size: 16,
              ),
              label: Text(
                isOwnedByMe
                    ? (canEdit ? 'Update Listing' : 'View Applications')
                    : (pet.status == 'Adopted' ? 'Already adopted' : 'Apply to Adopt'),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.outlined(
            onPressed: onReport,
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report listing',
          ),
        ],
      ),
    );
  }
}

class _MediaCarousel extends StatelessWidget {
  final int petId;
  final List<AdoptionMediaUiModel> media;
  final PageController controller;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;

  const _MediaCarousel({
    required this.petId,
    required this.media,
    required this.controller,
    required this.pageIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: controller,
          itemCount: media.length,
          onPageChanged: onPageChanged,
          itemBuilder: (_, i) {
            final item = media[i];
            if (item.isVideo) {
              return _VideoMediaHero(petId: petId, item: item, index: i);
            }
            return Image.network(
              item.displayUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, _, _) => const _PhotoFallback(),
            );
          },
        ),
        if (media.length > 1) ...[
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                media.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == pageIndex ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
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
          Positioned(
            top: 56,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${pageIndex + 1}/${media.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VideoMediaHero extends StatelessWidget {
  final int petId;
  final AdoptionMediaUiModel item;
  final int index;

  const _VideoMediaHero({
    required this.petId,
    required this.item,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final ratio =
        (item.width != null && item.height != null && item.height! > 0)
        ? item.width! / item.height!
        : 16 / 9;
    final url = item.playbackUrl;
    if (url.isEmpty) {
      return _VideoPlaceholder(thumbnailUrl: item.previewImageUrl);
    }

    return FeedVideoPlayer(
      url: url,
      visibilityKey: 'adoption-detail-$petId-$index',
      startMuted: true,
      enableAutoplay: false,
      aspectRatio: ratio,
      fit: BoxFit.cover,
      isDetailViewer: true,
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  final String? thumbnailUrl;

  const _VideoPlaceholder({this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    final thumb = thumbnailUrl?.trim() ?? '';
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumb.isNotEmpty)
          Image.network(
            thumb,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _PhotoFallback(),
          )
        else
          const _PhotoFallback(),
        Container(color: Colors.black.withValues(alpha: 0.18)),
        const Center(
          child: Icon(
            Icons.play_circle_fill,
            size: 72,
            color: Colors.white,
            shadows: [Shadow(blurRadius: 12, color: Colors.black45)],
          ),
        ),
      ],
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final String tooltip;

  const _OverlayIconButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: _OverlayIconDecoration(child: icon),
    );
  }
}

class _OverlayIconDecoration extends StatelessWidget {
  final Widget child;

  const _OverlayIconDecoration({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.photo_outlined, size: 40, color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _NoPhotoBanner extends StatelessWidget {
  final String species;
  const _NoPhotoBanner({required this.species});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final icon = switch (species) {
      'Cats' => Icons.pets_rounded,
      'Dogs' => Icons.cruelty_free_outlined,
      'Birds' => Icons.flutter_dash_rounded,
      'Rabbits' => Icons.emoji_nature_rounded,
      _ => Icons.favorite_border_rounded,
    };
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.2),
            cs.secondary.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Center(
        child: Icon(icon, size: 56, color: cs.primary.withValues(alpha: 0.6)),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.menuTitle(
                  context,
                ).copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(padding: const EdgeInsets.only(left: 24), child: child),
        ],
      ),
    );
  }
}

class _SafetyWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: Colors.amber.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: Colors.amber,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Do not send money before meeting the pet in person and reviewing health records. Meet in a safe, public place.',
              style: AppTypography.caption(
                context,
              ).copyWith(color: Colors.brown.shade800, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      'Adopted' => (Colors.blueGrey.shade700, Colors.blueGrey.shade50),
      'Paused' => (Colors.grey.shade700, Colors.grey.shade100),
      'Draft' => (Colors.grey.shade700, Colors.grey.shade100),
      'Pending Review' => (Colors.orange.shade800, Colors.orange.shade50),
      'Rejected' => (Colors.red.shade700, Colors.red.shade50),
      _ => (Colors.green.shade700, Colors.green.shade50),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  final String label;
  final bool positive;
  const _HealthChip({required this.label, required this.positive});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: positive
            ? Colors.green.shade50
            : cs.surfaceContainerHighest.withValues(alpha: 0.6),
        border: Border.all(
          color: positive ? Colors.green.shade200 : cs.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: positive ? Colors.green.shade700 : cs.onSurfaceVariant,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(20),
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
