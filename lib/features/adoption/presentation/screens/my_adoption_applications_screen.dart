import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_application_ui_model.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/adoption/presentation/screens/adoption_pet_detail_screen.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyAdoptionApplicationsScreen extends StatefulWidget {
  const MyAdoptionApplicationsScreen({super.key});

  @override
  State<MyAdoptionApplicationsScreen> createState() =>
      _MyAdoptionApplicationsScreenState();
}

class _MyAdoptionApplicationsScreenState
    extends State<MyAdoptionApplicationsScreen> {
  late final AdoptionRepository _repository;
  bool _isLoading = true;
  bool _requiresLogin = false;
  String? _error;
  List<AdoptionApplicationUiModel> _items = const [];

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
      final items = await _repository.fetchMyAdoptionApplications();
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
      appBar: AppBar(title: const Text('My Adoption Applications')),
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
                message: 'Sign in to view your adoption applications.',
                icon: Icons.lock_outline_rounded,
              )
            else if (_error != null)
              const _StateCard(
                title: 'Could not load applications',
                message:
                    'The adoption API is unavailable right now. Pull to refresh and try again.',
                icon: Icons.cloud_off_rounded,
              )
            else if (_items.isEmpty)
              const _StateCard(
                title: 'No applications yet',
                message: 'You have not submitted any adoption applications yet.',
                icon: Icons.assignment_turned_in_outlined,
              )
            else
              ..._items.map(
                (application) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: _ApplicationCard(
                    application: application,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdoptionPetDetailScreen(
                          pet: application.pet,
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

class _ApplicationCard extends StatelessWidget {
  final AdoptionApplicationUiModel application;
  final VoidCallback onTap;

  const _ApplicationCard({
    required this.application,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      application.pet.name,
                      style: AppTypography.menuTitle(
                        context,
                      ).copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      application.status,
                      style: AppTypography.meta(
                        context,
                      ).copyWith(color: cs.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${application.pet.species} • ${application.pet.breed}',
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
                      application.pet.location,
                      style: AppTypography.caption(
                        context,
                      ).copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Pet status: ${application.pet.status}',
                style: AppTypography.caption(
                  context,
                ).copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Submitted: ${application.submittedAtLabel}',
                style: AppTypography.caption(
                  context,
                ).copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
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
