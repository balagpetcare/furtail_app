import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/features/adoption/data/mock/adoption_pet_mock_data.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/adoption/presentation/screens/adoption_filter_screen.dart';
import 'package:furtail_app/features/adoption/presentation/screens/adoption_pet_detail_screen.dart';
import 'package:furtail_app/features/adoption/presentation/screens/create_adoption_listing_screen.dart';
import 'package:furtail_app/features/adoption/presentation/screens/my_adoption_applications_screen.dart';
import 'package:furtail_app/features/adoption/presentation/screens/my_adoption_listings_screen.dart';
import 'package:furtail_app/features/adoption/presentation/widgets/adoption_pet_card.dart';
import 'package:furtail_app/services/api_client.dart';

class AdoptionHomeScreen extends StatefulWidget {
  const AdoptionHomeScreen({super.key});

  @override
  State<AdoptionHomeScreen> createState() => _AdoptionHomeScreenState();
}

class _AdoptionHomeScreenState extends State<AdoptionHomeScreen> {
  static const List<String> _petTypes = [
    'Cats',
    'Dogs',
    'Birds',
    'Rabbits',
    'Other',
  ];

  String _selectedType = _petTypes.first;
  String _query = '';
  final Set<int> _savedPetIds = <int>{1};
  late final AdoptionRepository _repository;

  List<AdoptionPetUiModel> _sourcePets = const [];
  bool _isLoading = true;
  bool _usingPreviewData = false;
  String? _bannerMessage;

  @override
  void initState() {
    super.initState();
    _repository = AdoptionRepository(AdoptionRemoteDs(ApiClient()));
    _loadAdoptions();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final filteredPets = _filteredPets;
    final isCompact = MediaQuery.of(context).size.width < 720;
    return Scaffold(
      appBar: AppBar(title: const Text('Adoption')),
      body: RefreshIndicator(
        onRefresh: _refreshAdoptions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: [
            Text(
              'Find your next companion',
              style: AppTypography.sectionTitle(
                context,
              ).copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Browse categories, search listings, or start your own adoption post.',
              style: AppTypography.bodyRegular(
                context,
              ).copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search adoption listings',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(() => _query = ''),
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: cs.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdoptionFilterScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Filter'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            InkWell(
              onTap: () => _showPlaceholderSnackBar(
                'Location selection will be connected after adoption search filters are finalized.',
              ),
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.place_outlined, color: cs.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location',
                            style: AppTypography.caption(
                              context,
                            ).copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Bangladesh',
                            style: AppTypography.menuTitle(
                              context,
                            ).copyWith(color: cs.onSurface),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Pet Type',
              style: AppTypography.menuTitle(
                context,
              ).copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _petTypes.map((type) {
                return ChoiceChip(
                  label: Text(type),
                  selected: _selectedType == type,
                  onSelected: (_) => setState(() => _selectedType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Available Pets',
                    style: AppTypography.sectionTitle(
                      context,
                    ).copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyAdoptionApplicationsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: const Text('Applications'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildStateBanner(context),
            const SizedBox(height: AppSpacing.lg),
            if (_isLoading)
              _buildLoadingState(context)
            else if (filteredPets.isEmpty)
              _buildEmptyState(context)
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredPets.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isCompact ? 1 : 2,
                  mainAxisExtent: isCompact ? 330 : 340,
                  crossAxisSpacing: AppSpacing.lg,
                  mainAxisSpacing: AppSpacing.lg,
                ),
                itemBuilder: (context, index) {
                  final pet = filteredPets[index];
                  return AdoptionPetCard(
                    pet: pet,
                    isSaved: _savedPetIds.contains(pet.id),
                    onToggleSaved: () => _toggleSaved(pet.id),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdoptionPetDetailScreen(
                          pet: pet,
                          repository: _repository,
                          isSaved: _savedPetIds.contains(pet.id),
                          onToggleSaved: () => _toggleSaved(pet.id),
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateAdoptionListingScreen(),
                ),
              ),
              child: const Text('Create Adoption Listing'),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MyAdoptionListingsScreen(),
                ),
              ),
              child: const Text('My Adoption Listings'),
            ),
          ],
        ),
      ),
    );
  }

  List<AdoptionPetUiModel> get _filteredPets {
    return _sourcePets.where((pet) {
      final matchesType = pet.species == _selectedType;
      final q = _query.toLowerCase();
      final matchesQuery =
          q.isEmpty ||
          pet.name.toLowerCase().contains(q) ||
          pet.breed.toLowerCase().contains(q) ||
          pet.location.toLowerCase().contains(q) ||
          pet.ownerName.toLowerCase().contains(q);
      return matchesType && matchesQuery;
    }).toList();
  }

  Future<void> _refreshAdoptions() => _loadAdoptions(showSnackOnFallback: false);

  Future<void> _loadAdoptions({bool showSnackOnFallback = true}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final pets = await _repository.fetchAdoptions(limit: 50);
      if (!mounted) return;
      if (pets.isEmpty) {
        setState(() {
          _sourcePets = AdoptionPetMockData.pets;
          _usingPreviewData = true;
          _bannerMessage = 'No live adoption listings yet. Showing preview data.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _sourcePets = pets;
        _usingPreviewData = false;
        _bannerMessage = 'Showing live adoption listings from the API.';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sourcePets = AdoptionPetMockData.pets;
        _usingPreviewData = true;
        _bannerMessage = 'Live adoption API is unavailable. Showing preview data.';
        _isLoading = false;
      });
      if (showSnackOnFallback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load live adoption data.')),
        );
      }
    }
  }

  void _showPlaceholderSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleSaved(int petId) {
    setState(() {
      if (_savedPetIds.contains(petId)) {
        _savedPetIds.remove(petId);
      } else {
        _savedPetIds.add(petId);
      }
    });
  }

  Widget _buildStateBanner(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _usingPreviewData
                ? Icons.preview_outlined
                : Icons.cloud_done_outlined,
            color: cs.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _usingPreviewData ? 'Preview Data' : 'Live Adoption Data',
                  style: AppTypography.menuTitle(
                    context,
                  ).copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _bannerMessage ??
                      'Showing local preview data while the API connection is being prepared.',
                  style: AppTypography.caption(
                    context,
                  ).copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _refreshAdoptions,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload',
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Loading adoption listings...',
            style: AppTypography.bodyRegular(
              context,
            ).copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: cs.primary.withValues(alpha: 0.12),
            child: Icon(Icons.search_off_rounded, color: cs.primary, size: 30),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No adoption listings available yet.',
            textAlign: TextAlign.center,
            style: AppTypography.sectionTitle(
              context,
            ).copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Try another pet type or adjust your search terms.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyRegular(
              context,
            ).copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: _refreshAdoptions,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
