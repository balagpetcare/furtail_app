import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/adoption/presentation/screens/adoption_pet_detail_screen.dart';
import 'package:furtail_app/features/adoption/presentation/widgets/adoption_pet_card.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyAdoptionListingsScreen extends StatefulWidget {
  const MyAdoptionListingsScreen({super.key});

  @override
  State<MyAdoptionListingsScreen> createState() => _MyAdoptionListingsScreenState();
}

class _MyAdoptionListingsScreenState extends State<MyAdoptionListingsScreen> {
  late final AdoptionRepository _repository;
  bool _isLoading = true;
  bool _requiresLogin = false;
  String? _error;
  List<AdoptionPetUiModel> _items = const [];

  @override
  void initState() {
    super.initState();
    _repository = AdoptionRepository(AdoptionRemoteDs(ApiClient()));
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('token') ?? '').trim();
    if (token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _requiresLogin = true;
        _isLoading = false;
      });
      return;
    }

    try {
      final items = await _repository.fetchMyAdoptionListings();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Adoption Listings')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_requiresLogin)
              const _StateCard(
                title: 'Login required',
                message: 'Sign in to view your adoption listings.',
                icon: Icons.lock_outline_rounded,
              )
            else if (_error != null)
              const _StateCard(
                title: 'Could not load listings',
                message: 'The adoption API is unavailable right now. Pull to refresh and try again.',
                icon: Icons.cloud_off_rounded,
              )
            else if (_items.isEmpty)
              const _StateCard(
                title: 'No listings yet',
                message: 'You have not published any adoption listings yet.',
                icon: Icons.list_alt_rounded,
              )
            else
              ..._items.map(
                (pet) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: AdoptionPetCard(
                    pet: pet,
                    isSaved: false,
                    onToggleSaved: () {},
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdoptionPetDetailScreen(
                          pet: pet,
                          repository: _repository,
                          isSaved: false,
                          onToggleSaved: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _StateCard({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
          Icon(icon, size: 34, color: cs.primary),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTypography.sectionTitle(
              context,
            ).copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyRegular(
              context,
            ).copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
