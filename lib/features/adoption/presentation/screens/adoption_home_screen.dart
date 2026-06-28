import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:furtail_app/app/router/app_routes.dart';
import 'package:furtail_app/core/navigation/profile_navigation.dart';
import 'package:furtail_app/core/storage/local_storage.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/features/adoption/data/mock/adoption_pet_mock_data.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/adoption/presentation/screens/adoption_pet_detail_screen.dart';
import 'package:furtail_app/features/adoption/presentation/screens/create_adoption_listing_screen.dart';
import 'package:furtail_app/features/adoption/presentation/screens/my_adoption_applications_screen.dart';
import 'package:furtail_app/features/adoption/presentation/screens/my_adoption_listings_screen.dart';
import 'package:furtail_app/features/adoption/presentation/screens/listing_applications_screen.dart';
import 'package:furtail_app/features/adoption/presentation/widgets/adoption_comments_sheet.dart';
import 'package:furtail_app/features/adoption/presentation/widgets/adoption_pet_card.dart';
import 'package:furtail_app/services/api_client.dart';

const _speciesApiMap = {
  'Cats': 'CAT',
  'Dogs': 'DOG',
  'Birds': 'BIRD',
  'Rabbits': 'RABBIT',
  'Other': 'OTHER',
};

const _radiusOptions = [5, 10, 25, 50];

class AdoptionHomeScreen extends StatefulWidget {
  const AdoptionHomeScreen({super.key});

  @override
  State<AdoptionHomeScreen> createState() => _AdoptionHomeScreenState();
}

class _AdoptionHomeScreenState extends State<AdoptionHomeScreen> {
  late final AdoptionRepository _repository;
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  String? _speciesFilter;
  String? _genderFilter;
  bool _vaccinatedOnly = false;
  bool _availableOnly = true;
  int? _radiusKm;
  double? _userLat;
  double? _userLng;
  bool _gpsLoading = false;
  bool _savingComingSoon = false;

  List<AdoptionPetUiModel> _sourcePets = const [];
  bool _isLoading = true;
  bool _usingPreviewData = false;
  String? _statusMessage;
  String? _errorMessage;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _repository = AdoptionRepository(AdoptionRemoteDs(ApiClient()));
    _loadCurrentUserId();
    _loadAdoptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdoptions({bool showSnackOnFallback = true}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pets = await _repository.fetchAdoptions(
        limit: 50,
        species: _speciesFilter != null ? _speciesApiMap[_speciesFilter] : null,
        nearLat: _userLat,
        nearLng: _userLng,
        radiusKm: _radiusKm,
      );

      if (!mounted) return;
      setState(() {
        _sourcePets = pets.isEmpty ? AdoptionPetMockData.pets : pets;
        _usingPreviewData = pets.isEmpty;
        _statusMessage = pets.isEmpty
            ? 'Preview data is showing because no live listings were returned.'
            : null;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sourcePets = AdoptionPetMockData.pets;
        _usingPreviewData = true;
        _statusMessage =
            'Preview data is showing because live listings could not load.';
        _errorMessage = 'Could not load live adoption listings.';
        _isLoading = false;
      });
      if (showSnackOnFallback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load live adoption listings.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await LocalStorage.getUserId();
    if (!mounted) return;
    setState(() => _currentUserId = userId);
  }

  Future<void> _refreshAdoptions() =>
      _loadAdoptions(showSnackOnFallback: false);

  List<AdoptionPetUiModel> get _filteredPets {
    return _sourcePets.where((pet) {
      if (_genderFilter != null) {
        final gender = pet.gender.toUpperCase();
        if (_genderFilter == 'MALE' && gender != 'MALE') return false;
        if (_genderFilter == 'FEMALE' && gender != 'FEMALE') return false;
      }

      if (_vaccinatedOnly && !pet.vaccinated) return false;

      if (_availableOnly) {
        final status = pet.status;
        final isAvailable =
            status == 'Available' ||
            status == 'Published' ||
            status == 'Approved';
        if (!isAvailable) return false;
      }

      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final matches =
            pet.name.toLowerCase().contains(q) ||
            pet.breed.toLowerCase().contains(q) ||
            pet.species.toLowerCase().contains(q) ||
            pet.location.toLowerCase().contains(q);
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  int get _activeFilterCount {
    var count = 0;
    if (_speciesFilter != null) count++;
    if (_genderFilter != null) count++;
    if (_vaccinatedOnly) count++;
    if (!_availableOnly) count++;
    if (_radiusKm != null) count++;
    return count;
  }

  bool get _hasActiveFilters => _activeFilterCount > 0;

  void _clearFilters() {
    setState(() {
      _speciesFilter = null;
      _genderFilter = null;
      _vaccinatedOnly = false;
      _availableOnly = true;
      _radiusKm = null;
    });
    _loadAdoptions(showSnackOnFallback: false);
  }

  Future<bool> _captureLocation() async {
    setState(() => _gpsLoading = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location services are off. Enable GPS and try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }

      final permission = await Permission.location.request();
      if (!permission.isGranted) {
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return true;
      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
      });
      return true;
    } catch (_) {
      return false;
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdoptionFilterSheet(
        speciesFilter: _speciesFilter,
        genderFilter: _genderFilter,
        vaccinatedOnly: _vaccinatedOnly,
        availableOnly: _availableOnly,
        radiusKm: _radiusKm,
        hasLocation: _userLat != null && _userLng != null,
        gpsLoading: _gpsLoading,
        onCaptureLocation: _captureLocation,
        onApply: (species, gender, vaccinated, available, radius) {
          setState(() {
            _speciesFilter = species;
            _genderFilter = gender;
            _vaccinatedOnly = vaccinated;
            _availableOnly = available;
            _radiusKm = radius;
          });
          _loadAdoptions(showSnackOnFallback: false);
        },
        onClear: _clearFilters,
      ),
    );
  }

  void _updatePetInFeed(AdoptionPetUiModel updated) {
    if (!mounted) return;
    setState(() {
      _sourcePets = _sourcePets
          .map((pet) => pet.id == updated.id ? updated : pet)
          .toList();
    });
  }

  void _updateCommentCount(int adoptionId, int count) {
    if (!mounted) return;
    setState(() {
      _sourcePets = _sourcePets
          .map(
            (pet) => pet.id == adoptionId
                ? pet.copyWith(commentCount: count)
                : pet,
          )
          .toList();
    });
  }

  Future<void> _toggleFavorite(AdoptionPetUiModel pet) async {
    if (_usingPreviewData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favorite actions are disabled in preview data mode.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final next = !pet.isFavoritedByMe;
    final optimistic = pet.copyWith(
      isFavoritedByMe: next,
      favoriteCount: (pet.favoriteCount + (next ? 1 : -1)).clamp(0, 1 << 30),
    );
    _updatePetInFeed(optimistic);

    try {
      final updated = next
          ? await _repository.favoriteAdoption(pet.id)
          : await _repository.unfavoriteAdoption(pet.id);
      if (!mounted) return;
      _updatePetInFeed(updated);
    } catch (e) {
      if (!mounted) return;
      _updatePetInFeed(pet);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update favorite: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openDetail(AdoptionPetUiModel pet) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdoptionPetDetailScreen(
          pet: pet,
          repository: _repository,
          onPetChanged: _updatePetInFeed,
        ),
      ),
    );
  }

  void _openCreateListing() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateAdoptionListingScreen()),
    );
  }

  void _openMyListings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MyAdoptionListingsScreen()));
  }

  void _openMyApplications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyAdoptionApplicationsScreen()),
    );
  }

  void _showSaveComingSoon() {
    if (_savingComingSoon || !mounted) return;
    _savingComingSoon = true;
    ScaffoldMessenger.of(context)
        .showSnackBar(
          const SnackBar(
            content: Text('Saved adoption listings will land here soon.'),
            behavior: SnackBarBehavior.floating,
          ),
        )
        .closed
        .whenComplete(() => _savingComingSoon = false);
  }

  Future<void> _openOwnerProfile(AdoptionPetUiModel pet) {
    return ProfileNavigation.openUserProfile(context, pet.ownerUserId);
  }

  bool _isOwnedByMe(AdoptionPetUiModel pet) =>
      _currentUserId != null && pet.ownerUserId == _currentUserId;

  void _handleCardMenuAction(
    AdoptionPetUiModel pet,
    AdoptionCardMenuAction action,
  ) {
    switch (action) {
      case AdoptionCardMenuAction.shareListing:
        ShareService.share(context, type: 'pet', id: pet.id);
        break;
      case AdoptionCardMenuAction.saveListing:
        _showSaveComingSoon();
        break;
      case AdoptionCardMenuAction.reportListing:
        _openDetail(pet);
        break;
      case AdoptionCardMenuAction.editListing:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CreateAdoptionListingScreen(existingListing: pet),
          ),
        ).then((updated) {
          if (updated == true) {
            _refreshAdoptions();
          }
        });
        break;
      case AdoptionCardMenuAction.updateStatus:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ListingApplicationsScreen(
              adoptionId: pet.id,
              petName: pet.name,
            ),
          ),
        ).then((_) => _refreshAdoptions());
        break;
      case AdoptionCardMenuAction.archiveListing:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Owner archive action is not available in this flow yet.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredPets = _filteredPets;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed(AppRoutes.home);
            }
          },
        ),
        title: const Text('Pet Adoption'),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'My Adoption Activity',
            onSelected: (value) {
              if (value == 'listings') {
                _openMyListings();
              } else if (value == 'applications') {
                _openMyApplications();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'listings',
                child: Row(
                  children: [
                    Icon(Icons.list_alt_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('My Adoption Listings'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'applications',
                child: Row(
                  children: [
                    Icon(Icons.assignment_ind_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('My Applications'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refreshAdoptions,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildTopToolbar(context)),
              if (_hasActiveFilters)
                SliverToBoxAdapter(child: _buildActiveFiltersRow(context)),
              if (_usingPreviewData || _errorMessage != null)
                SliverToBoxAdapter(child: _buildFeedStatusBanner(context)),
              SliverToBoxAdapter(
                child: _buildResultsHeader(context, filteredPets.length),
              ),
              if (_isLoading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  sliver: SliverList.separated(
                    itemCount: 3,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) =>
                        const AdoptionPetCardSkeleton(),
                  ),
                )
              else if (_errorMessage != null && _sourcePets.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(context),
                )
              else if (filteredPets.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(context),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  sliver: SliverList.separated(
                    itemCount: filteredPets.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final pet = filteredPets[index];
                      return AdoptionPetCard(
                        pet: pet,
                        isFavorited: pet.isFavoritedByMe,
                        isOwnedByMe: _isOwnedByMe(pet),
                        onToggleFavorite: () => _toggleFavorite(pet),
                        onOpenDetails: () => _openDetail(pet),
                        onOwnerTap: () => _openOwnerProfile(pet),
                        onMenuSelected: (action) =>
                            _handleCardMenuAction(pet, action),
                        onComment: () {
                          showAdoptionCommentsSheet(
                            context,
                            pet: pet,
                            repository: _repository,
                            onCountChanged: (count) =>
                                _updateCommentCount(pet.id, count),
                          );
                        },
                        onShare: () => ShareService.share(
                          context,
                          type: 'pet',
                          id: pet.id,
                        ),
                        onSave: _showSaveComingSoon,
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopToolbar(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search pets, breeds, locations',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                isDense: true,
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary, width: 1.25),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton.icon(
            onPressed: _openCreateListing,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              backgroundColor: cs.primaryContainer.withValues(alpha: 0.55),
              foregroundColor: cs.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('Create'),
          ),
          const SizedBox(width: AppSpacing.xs),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton.filledTonal(
                onPressed: _openFilterSheet,
                tooltip: 'Filters',
                icon: const Icon(Icons.tune_rounded, size: 18),
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_activeFilterCount',
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedStatusBanner(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _errorMessage != null
              ? cs.errorContainer.withValues(alpha: 0.45)
              : cs.tertiaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _errorMessage != null
                ? cs.error.withValues(alpha: 0.15)
                : cs.tertiary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _errorMessage != null
                  ? Icons.info_outline_rounded
                  : Icons.preview_outlined,
              size: 16,
              color: _errorMessage != null ? cs.error : cs.tertiary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage ??
                    _statusMessage ??
                    'Preview data is shown here.',
                style: AppTypography.caption(context).copyWith(
                  color: _errorMessage != null
                      ? cs.onErrorContainer
                      : cs.onTertiaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: _refreshAdoptions,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFiltersRow(BuildContext context) {
    final chips = <Widget>[];

    if (_speciesFilter != null) {
      chips.add(
        _ActiveFilterChip(
          label: _speciesFilter!,
          onRemove: () {
            setState(() => _speciesFilter = null);
            _loadAdoptions(showSnackOnFallback: false);
          },
        ),
      );
    }

    if (_genderFilter != null) {
      chips.add(
        _ActiveFilterChip(
          label: _genderFilter == 'MALE' ? 'Male' : 'Female',
          onRemove: () {
            setState(() => _genderFilter = null);
            _loadAdoptions(showSnackOnFallback: false);
          },
        ),
      );
    }

    if (_vaccinatedOnly) {
      chips.add(
        _ActiveFilterChip(
          label: 'Vaccinated',
          onRemove: () {
            setState(() => _vaccinatedOnly = false);
            _loadAdoptions(showSnackOnFallback: false);
          },
        ),
      );
    }

    if (!_availableOnly) {
      chips.add(
        _ActiveFilterChip(
          label: 'Show all statuses',
          onRemove: () {
            setState(() => _availableOnly = true);
            _loadAdoptions(showSnackOnFallback: false);
          },
        ),
      );
    }

    if (_radiusKm != null) {
      chips.add(
        _ActiveFilterChip(
          label: '${_radiusKm}km radius',
          onRemove: () {
            setState(() => _radiusKm = null);
            _loadAdoptions(showSnackOnFallback: false);
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        0,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: chips,
      ),
    );
  }

  Widget _buildResultsHeader(BuildContext context, int count) {
    final cs = context.colorScheme;
    final label = _isLoading
        ? 'Loading pets'
        : _usingPreviewData
        ? '$count preview pets'
        : '$count ${count == 1 ? 'pet' : 'pets'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.menuTitle(
              context,
            ).copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
          const Spacer(),
          if (_radiusKm != null && !_usingPreviewData)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Nearby',
                style: AppTypography.caption(
                  context,
                ).copyWith(color: cs.onSecondaryContainer, fontSize: 10),
              ),
            ),
          if (!_isLoading)
            PopupMenuButton<_AdoptionHeaderAction>(
              tooltip: 'More adoption actions',
              onSelected: (value) {
                switch (value) {
                  case _AdoptionHeaderAction.myListings:
                    _openMyListings();
                    break;
                  case _AdoptionHeaderAction.myApplications:
                    _openMyApplications();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _AdoptionHeaderAction.myListings,
                  child: Text('My Adoption Listings'),
                ),
                PopupMenuItem(
                  value: _AdoptionHeaderAction.myApplications,
                  child: Text('My Applications'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: cs.primary.withValues(alpha: 0.1),
            child: Icon(Icons.search_off_rounded, color: cs.primary, size: 28),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No pets found',
            style: AppTypography.menuTitle(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _hasActiveFilters
                ? 'Try clearing a filter or adjusting the search.'
                : 'Pull down to refresh or try a different search.',
            textAlign: TextAlign.center,
            style: AppTypography.caption(
              context,
            ).copyWith(color: cs.onSurfaceVariant),
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: cs.error.withValues(alpha: 0.12),
            child: Icon(Icons.cloud_off_rounded, color: cs.error, size: 28),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Could not load adoption listings',
            textAlign: TextAlign.center,
            style: AppTypography.menuTitle(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pull to refresh or retry loading the feed.',
            textAlign: TextAlign.center,
            style: AppTypography.caption(
              context,
            ).copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _refreshAdoptions,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

enum _AdoptionHeaderAction { myListings, myApplications }

class _AdoptionFilterSheet extends StatefulWidget {
  final String? speciesFilter;
  final String? genderFilter;
  final bool vaccinatedOnly;
  final bool availableOnly;
  final int? radiusKm;
  final bool hasLocation;
  final bool gpsLoading;
  final Future<bool> Function() onCaptureLocation;
  final void Function(String?, String?, bool, bool, int?) onApply;
  final VoidCallback onClear;

  const _AdoptionFilterSheet({
    required this.speciesFilter,
    required this.genderFilter,
    required this.vaccinatedOnly,
    required this.availableOnly,
    required this.radiusKm,
    required this.hasLocation,
    required this.gpsLoading,
    required this.onCaptureLocation,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_AdoptionFilterSheet> createState() => _AdoptionFilterSheetState();
}

class _AdoptionFilterSheetState extends State<_AdoptionFilterSheet> {
  late String? _species;
  late String? _gender;
  late bool _vaccinated;
  late bool _available;
  late int? _radius;
  late bool _hasLocation;

  @override
  void initState() {
    super.initState();
    _species = widget.speciesFilter;
    _gender = widget.genderFilter;
    _vaccinated = widget.vaccinatedOnly;
    _available = widget.availableOnly;
    _radius = widget.radiusKm;
    _hasLocation = widget.hasLocation;
  }

  bool get _hasActiveFilters =>
      _species != null ||
      _gender != null ||
      _vaccinated ||
      !_available ||
      _radius != null;

  bool get _showRadiusSection => _hasLocation || widget.gpsLoading;

  Future<void> _enableLocation() async {
    final ok = await widget.onCaptureLocation();
    if (!mounted) return;
    if (ok) {
      setState(() => _hasLocation = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Material(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filter pets',
                        style: AppTypography.sectionTitle(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_hasActiveFilters)
                      TextButton(
                        onPressed: () {
                          widget.onClear();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Clear all'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  children: [
                    _FilterSection(
                      title: 'Animal type',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: _species == null,
                            onSelected: (_) => setState(() => _species = null),
                          ),
                          ..._speciesApiMap.keys.map(
                            (label) => ChoiceChip(
                              label: Text(label),
                              selected: _species == label,
                              onSelected: (_) =>
                                  setState(() => _species = label),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _FilterSection(
                      title: 'Gender',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          ChoiceChip(
                            label: const Text('Any'),
                            selected: _gender == null,
                            onSelected: (_) => setState(() => _gender = null),
                          ),
                          ChoiceChip(
                            label: const Text('Male'),
                            selected: _gender == 'MALE',
                            onSelected: (_) => setState(() => _gender = 'MALE'),
                          ),
                          ChoiceChip(
                            label: const Text('Female'),
                            selected: _gender == 'FEMALE',
                            onSelected: (_) =>
                                setState(() => _gender = 'FEMALE'),
                          ),
                        ],
                      ),
                    ),
                    _FilterSection(
                      title: 'Availability',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          FilterChip(
                            label: const Text('Vaccinated only'),
                            selected: _vaccinated,
                            onSelected: (value) =>
                                setState(() => _vaccinated = value),
                          ),
                          FilterChip(
                            label: const Text('Available only'),
                            selected: _available,
                            onSelected: (value) =>
                                setState(() => _available = value),
                          ),
                        ],
                      ),
                    ),
                    _FilterSection(
                      title: 'Radius',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_hasLocation)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withValues(
                                  alpha: 0.45,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cs.outlineVariant),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Enable location to filter nearby listings.',
                                      style: AppTypography.caption(
                                        context,
                                      ).copyWith(color: cs.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!_hasLocation) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: widget.gpsLoading
                                    ? null
                                    : _enableLocation,
                                icon: widget.gpsLoading
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.my_location_rounded,
                                        size: 16,
                                      ),
                                label: const Text('Enable location'),
                              ),
                            ),
                          ],
                          if (_showRadiusSection) ...[
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                ChoiceChip(
                                  label: const Text('Any'),
                                  selected: _radius == null,
                                  onSelected: (_) =>
                                      setState(() => _radius = null),
                                ),
                                ..._radiusOptions.map(
                                  (km) => ChoiceChip(
                                    label: Text('$km km'),
                                    selected: _radius == km,
                                    onSelected: (_) =>
                                        setState(() => _radius = km),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Radius filtering uses your current location when available.',
                              style: AppTypography.caption(context).copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border(top: BorderSide(color: cs.outlineVariant)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _hasActiveFilters
                              ? () {
                                  setState(() {
                                    _species = null;
                                    _gender = null;
                                    _vaccinated = false;
                                    _available = true;
                                    _radius = null;
                                  });
                                }
                              : null,
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            widget.onApply(
                              _species,
                              _gender,
                              _vaccinated,
                              _available,
                              _radius,
                            );
                            Navigator.of(context).pop();
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
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

class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTypography.caption(context).copyWith(
              color: context.colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      deleteIcon: const Icon(Icons.close, size: 12),
      onDeleted: onRemove,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
