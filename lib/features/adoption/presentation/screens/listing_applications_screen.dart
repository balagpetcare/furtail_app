import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_application_ui_model.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/adoption/domain/adoption_fit_score.dart';
import 'package:furtail_app/features/adoption/presentation/screens/application_detail_screen.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:url_launcher/url_launcher.dart';

const _kStatuses = [
  ('All', ''),
  ('Submitted', 'SUBMITTED'),
  ('Shortlisted', 'SHORTLISTED'),
  ('Interview', 'INTERVIEW_SCHEDULED'),
  ('Approved', 'APPROVED'),
  ('Rejected', 'REJECTED'),
];

enum _SortMode { bestMatch, newest, status }

class ListingApplicationsScreen extends StatefulWidget {
  final int adoptionId;
  final String petName;

  const ListingApplicationsScreen({
    super.key,
    required this.adoptionId,
    required this.petName,
  });

  @override
  State<ListingApplicationsScreen> createState() =>
      _ListingApplicationsScreenState();
}

class _ListingApplicationsScreenState extends State<ListingApplicationsScreen> {
  late final AdoptionRepository _repository;
  bool _isLoading = true;
  bool _requiresLogin = false;
  String? _error;
  List<AdoptionApplicationUiModel> _items = const [];
  String _filterStatus = '';
  _SortMode _sort = _SortMode.bestMatch;

  @override
  void initState() {
    super.initState();
    _repository = AdoptionRepository(AdoptionRemoteDs(ApiClient()));
    _load();
  }

  Future<void> _load() async {
    final hasSession = await SecureStorageService().hasSession;
    if (!hasSession) {
      if (!mounted) return;
      setState(() {
        _requiresLogin = true;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final items = await _repository.fetchApplicationsForMyListing(
        widget.adoptionId,
        status: _filterStatus.isEmpty ? null : _filterStatus,
      );
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

  List<AdoptionApplicationUiModel> get _sorted {
    final list = List<AdoptionApplicationUiModel>.from(_items);
    switch (_sort) {
      case _SortMode.bestMatch:
        list.sort((a, b) {
          final sa = AdoptionFitScore.compute(a).score;
          final sb = AdoptionFitScore.compute(b).score;
          return sb.compareTo(sa);
        });
      case _SortMode.newest:
        list.sort((a, b) {
          final da = a.submittedAt ?? DateTime(2000);
          final db = b.submittedAt ?? DateTime(2000);
          return db.compareTo(da);
        });
      case _SortMode.status:
        const order = [
          'SHORTLISTED',
          'INTERVIEW_SCHEDULED',
          'SUBMITTED',
          'VIEWED',
          'OWNER_REVIEW',
          'APPROVED',
          'REJECTED',
          'CANCELLED',
        ];
        list.sort((a, b) {
          final ia = order.indexOf(a.rawStatus);
          final ib = order.indexOf(b.rawStatus);
          return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Applicants: ${widget.petName}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<_SortMode>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _SortMode.bestMatch,
                child: Text('Best Match first'),
              ),
              PopupMenuItem(
                value: _SortMode.newest,
                child: Text('Newest first'),
              ),
              PopupMenuItem(value: _SortMode.status, child: Text('By status')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            selected: _filterStatus,
            onChanged: (v) {
              setState(() => _filterStatus = v);
              _load();
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(sorted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<AdoptionApplicationUiModel> sorted) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_requiresLogin) {
      return const _StateMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Login required',
        message: 'Sign in to view applications.',
      );
    }
    if (_error != null) {
      return _StateMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load applications',
        message: 'Pull to refresh and try again.',
        action: TextButton(onPressed: _load, child: const Text('Retry')),
      );
    }
    if (sorted.isEmpty) {
      return const _StateMessage(
        icon: Icons.description_outlined,
        title: 'No applications',
        message: 'No applicants for this filter yet.',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      itemCount: sorted.length,
      separatorBuilder: (context, i) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => _ApplicationCard(
        app: sorted[i],
        onTap: () async {
          final updated = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => ApplicationDetailScreen(
                applicationId: sorted[i].id,
                repository: _repository,
              ),
            ),
          );
          if (updated == true) _load();
        },
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _FilterBar({required this.selected, required this.onChanged});

  @override
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 6,
        ),
        children: _kStatuses.map((t) {
          final isSelected = selected == t.$2;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: FilterChip(
              label: Text(t.$1),
              selected: isSelected,
              onSelected: (_) => onChanged(t.$2),
              selectedColor: Colors.blue,
              checkmarkColor: Colors.white,
              backgroundColor: Colors.white,
              shadowColor: Colors.transparent,
              selectedShadowColor: Colors.transparent,
              side: BorderSide(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Application card ──────────────────────────────────────────────────────────

class _ApplicationCard extends StatelessWidget {
  final AdoptionApplicationUiModel app;
  final VoidCallback onTap;

  const _ApplicationCard({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final fit = AdoptionFitScore.compute(app);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: avatar + name + fit badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(url: app.applicantAvatarUrl, radius: 22),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.applicantName,
                          style: AppTypography.menuTitle(
                            context,
                          ).copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (app.applicantUsername.isNotEmpty)
                          Text(
                            '@${app.applicantUsername}',
                            style: TextStyle(fontSize: 12, color: cs.outline),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FitBadge(fit: fit),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Status + date
              Row(
                children: [
                  _StatusBadge(rawStatus: app.rawStatus, label: app.status),
                  const Spacer(),
                  Text(
                    app.submittedAtLabel,
                    style: TextStyle(fontSize: 11, color: cs.outline),
                  ),
                ],
              ),

              // Message preview
              if (app.message.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  app.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],

              // Location
              if (app.applicantCityAreaText.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: cs.outline,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        app.applicantCityAreaText,
                        style: TextStyle(fontSize: 12, color: cs.outline),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Tags
              if (fit.tags.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: fit.tags.map((t) => _TagChip(label: t)).toList(),
                ),
              ],

              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),

              // Quick actions
              Row(
                children: [
                  if (app.applicantPhone.isNotEmpty)
                    _QuickAction(
                      icon: Icons.phone_outlined,
                      label: 'Call',
                      onTap: () => _launchTel(app.applicantPhone),
                    ),
                  if (app.applicantWhatsappPhone.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _QuickAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'WhatsApp',
                      onTap: () => _launchWhatsapp(app.applicantWhatsappPhone),
                    ),
                  ],
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.chevron_right, size: 14),
                    label: const Text('View'),
                    style: TextButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchTel(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'\s+'), '')}');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _launchWhatsapp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String url;
  final double radius;

  const _Avatar({required this.url, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty ? Icon(Icons.person, size: radius) : null,
    );
  }
}

class _FitBadge extends StatelessWidget {
  final AdoptionFitScore fit;

  const _FitBadge({required this.fit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fit.labelBg(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${fit.scoreText} ${fit.labelText}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fit.labelColor(context),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String rawStatus;
  final String label;

  const _StatusBadge({required this.rawStatus, required this.label});

  Color _statusColor() {
    switch (rawStatus.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
      case 'CANCELLED':
        return Colors.red;
      case 'SHORTLISTED':
        return Colors.purple;
      case 'INTERVIEW_SCHEDULED':
        return Colors.orange;
      case 'VIEWED':
      case 'OWNER_REVIEW':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _statusColor();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        textStyle: const TextStyle(fontSize: 12),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: cs.primary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTypography.sectionTitle(context)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
