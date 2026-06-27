import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_application_ui_model.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/adoption/presentation/screens/application_detail_screen.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ListingApplicationsScreen extends StatefulWidget {
  final int adoptionId;
  final String petName;

  const ListingApplicationsScreen({
    super.key,
    required this.adoptionId,
    required this.petName,
  });

  @override
  State<ListingApplicationsScreen> createState() => _ListingApplicationsScreenState();
}

class _ListingApplicationsScreenState extends State<ListingApplicationsScreen> {
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
      final items = await _repository.fetchApplicationsForMyListing(widget.adoptionId);
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

  Color _statusColor(String status, ColorScheme cs) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
      case 'CANCELLED':
        return Colors.red;
      case 'SHORTLISTED':
        return Colors.purple;
      case 'INTERVIEW SCHEDULED':
      case 'INTERVIEW_SCHEDULED':
        return Colors.orange;
      case 'VIEWED':
      case 'OWNER_REVIEW':
        return Colors.blue;
      default:
        return cs.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Applications: ${widget.petName}'),
      ),
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
                message: 'Sign in to view applications.',
                icon: Icons.lock_outline_rounded,
              )
            else if (_error != null)
              const _StateCard(
                title: 'Could not load applications',
                message: 'The adoption API is unavailable right now. Pull to refresh and try again.',
                icon: Icons.cloud_off_rounded,
              )
            else if (_items.isEmpty)
              const _StateCard(
                title: 'No applications',
                message: 'No one has applied to adopt this pet yet.',
                icon: Icons.description_outlined,
              )
            else
              ..._items.map(
                (app) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    leading: CircleAvatar(
                      backgroundImage: app.applicantAvatarUrl.isNotEmpty
                          ? NetworkImage(app.applicantAvatarUrl)
                          : null,
                      child: app.applicantAvatarUrl.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            app.applicantName,
                            style: AppTypography.menuTitle(context),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(app.status, cs).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _statusColor(app.status, cs).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            app.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _statusColor(app.status, cs),
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        if (app.message.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              app.message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        Text(
                          'Submitted: ${app.submittedAtLabel}',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.outline,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final updated = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ApplicationDetailScreen(
                            applicationId: app.id,
                            repository: _repository,
                          ),
                        ),
                      );
                      if (updated == true) {
                        _load();
                      }
                    },
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
