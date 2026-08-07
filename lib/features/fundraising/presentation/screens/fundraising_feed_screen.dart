import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/fundraising_error_mapper.dart';
import '../../data/models/fundraising_models.dart';
import '../../data/repositories/fundraising_repository.dart';
import '../providers/fundraising_providers.dart';
import '../widgets/fundraising_card.dart';
import '../widgets/fundraising_status_views.dart';
import 'fundraising_common_scaffold.dart';
import 'fundraising_create_screen.dart';
import 'fundraising_details_screen.dart';
import 'fundraising_edit_screen.dart';

typedef FundraisingFeedPageLoader =
    Future<FundraisingPage<FundraisingCampaign>> Function(
      FundraisingFeedQuery query,
      String? cursor,
    );

class FundraisingFeedScreen extends ConsumerStatefulWidget {
  const FundraisingFeedScreen({
    super.key,
    this.pageLoader,
    this.autoLoad = true,
    this.onOpenCreate,
    this.onOpenDetails,
    this.onOpenEdit,
    this.onOpenMyFundraisers,
    this.onOpenMyDonations,
    this.onOpenVerification,
  });

  final FundraisingFeedPageLoader? pageLoader;
  final bool autoLoad;
  final VoidCallback? onOpenCreate;
  final ValueChanged<int>? onOpenDetails;
  final Future<bool?> Function(int campaignId)? onOpenEdit;
  final VoidCallback? onOpenMyFundraisers;
  final VoidCallback? onOpenMyDonations;
  final VoidCallback? onOpenVerification;

  @override
  ConsumerState<FundraisingFeedScreen> createState() =>
      _FundraisingFeedScreenState();
}

class _FundraisingFeedScreenState extends ConsumerState<FundraisingFeedScreen> {
  static const List<_FilterOption> _categoryOptions = <_FilterOption>[
    _FilterOption(value: 'TREATMENT', label: 'Treatment'),
    _FilterOption(value: 'RESCUE', label: 'Rescue'),
    _FilterOption(value: 'SHELTER', label: 'Shelter'),
    _FilterOption(value: 'FOOD', label: 'Food'),
    _FilterOption(value: 'EQUIPMENT', label: 'Equipment'),
    _FilterOption(value: 'OTHER', label: 'Other'),
  ];

  static const List<_FilterOption> _beneficiaryOptions = <_FilterOption>[
    _FilterOption(value: 'PET', label: 'Pet'),
    _FilterOption(value: 'PERSON', label: 'Person'),
    _FilterOption(value: 'SHELTER', label: 'Shelter'),
    _FilterOption(value: 'ORGANIZATION', label: 'Organization'),
    _FilterOption(value: 'COMMUNITY', label: 'Community'),
    _FilterOption(value: 'OTHER', label: 'Other'),
  ];

  static const List<_FilterOption> _urgencyOptions = <_FilterOption>[
    _FilterOption(value: 'LOW', label: 'Low'),
    _FilterOption(value: 'MEDIUM', label: 'Medium'),
    _FilterOption(value: 'HIGH', label: 'High'),
    _FilterOption(value: 'CRITICAL', label: 'Critical'),
  ];

  static const List<_FilterOption> _myStatusOptions = <_FilterOption>[
    _FilterOption(value: 'PENDING_REVIEW', label: 'Pending review'),
    _FilterOption(value: 'APPROVED', label: 'Approved'),
    _FilterOption(value: 'PUBLISHED', label: 'Published'),
    _FilterOption(value: 'ACTIVE', label: 'Active'),
    _FilterOption(value: 'PAUSED', label: 'Paused'),
    _FilterOption(value: 'FUNDED', label: 'Funded'),
    _FilterOption(value: 'COMPLETED', label: 'Completed'),
    _FilterOption(value: 'EXPIRED', label: 'Expired'),
    _FilterOption(value: 'CANCELLED', label: 'Cancelled'),
    _FilterOption(value: 'REJECTED', label: 'Rejected'),
    _FilterOption(value: 'ARCHIVED', label: 'Archived'),
    _FilterOption(value: 'SUSPENDED', label: 'Suspended'),
  ];

  final List<FundraisingCampaign> _items = <FundraisingCampaign>[];
  final ScrollController _scrollController = ScrollController();

  bool _initialLoading = false;
  bool _refreshing = false;
  bool _loadingMore = false;
  final Set<int> _busyCampaignActions = <int>{};
  Object? _error;
  String? _nextCursor;
  FundraisingFeedQuery? _lastQuery;

  bool get _hasAnyLoading => _initialLoading || _refreshing || _loadingMore;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    ref.listenManual<FundraisingFeedQuery>(fundraisingFeedQueryProvider, (
      previous,
      next,
    ) {
      if (previous != next) {
        unawaited(_refresh(reset: true));
      }
    });
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_refresh(reset: true));
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<FundraisingPage<FundraisingCampaign>> _loadPage(
    FundraisingFeedQuery query,
    String? cursor,
  ) {
    final injected = widget.pageLoader;
    if (injected != null) {
      return injected(query, cursor);
    }
    final repo = ref.read(fundraisingRepositoryProvider);
    if (query.view == FundraisingFeedView.myFundraisers) {
      return repo.fetchMyCampaignsPage(
        limit: 20,
        cursor: cursor,
        verified: query.verified,
        category: query.category,
        beneficiaryType: query.beneficiaryType,
        urgency: query.urgency,
        status: query.status,
        location: query.location,
        sort: query.sort.apiValue,
      );
    }
    return repo.fetchFeedPage(
      limit: 20,
      cursor: cursor,
      verified: query.verified,
      category: query.category,
      beneficiaryType: query.beneficiaryType,
      urgency: query.urgency,
      status: query.status,
      location: query.location,
      sort: query.sort.apiValue,
    );
  }

  Future<void> _refresh({required bool reset}) async {
    if (_loadingMore || (_initialLoading && !reset) || (_refreshing && reset)) {
      return;
    }
    final query = ref.read(fundraisingFeedQueryProvider);
    setState(() {
      _error = null;
      if (reset) {
        _nextCursor = null;
        if (_items.isEmpty) {
          _initialLoading = true;
        } else {
          _refreshing = true;
        }
      } else {
        _loadingMore = true;
      }
    });

    try {
      final page = await _loadPage(query, reset ? null : _nextCursor);
      if (!mounted) return;
      setState(() {
        _lastQuery = query;
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          final existingIds = _items.map((item) => item.id).toSet();
          for (final item in page.items) {
            if (existingIds.add(item.id)) {
              _items.add(item);
            }
          }
        }
        _nextCursor = page.nextCursor;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _refreshing = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _handleScroll() {
    if (_hasAnyLoading ||
        _nextCursor == null ||
        !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 200) {
      unawaited(_refresh(reset: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(fundraisingFeedQueryProvider);
    final hasCustomFilters = _hasCustomFilters(query);

    return FundraisingCommonScaffold(
      title: query.view == FundraisingFeedView.publicFeed
          ? 'Fundraising'
          : 'My fundraisers',
      showBack: true,
      showDonationHistory: true,
      showMyFundraisers: true,
      showFilters: true,
      showVerification: true,
      showCreate: true,
      onOpenFilters: () => _openFilters(context),
      onOpenCreate: widget.onOpenCreate,
      onOpenMyFundraisers: _activateMyFundraisers,
      onOpenDonationHistory: widget.onOpenMyDonations,
      onOpenVerification: widget.onOpenVerification,
      body: _buildBody(context, hasCustomFilters, query),
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool hasCustomFilters,
    FundraisingFeedQuery query,
  ) {
    if (_initialLoading) {
      return const FundraisingLoadingView(message: 'Loading fundraisers...');
    }

    if (_error != null && _items.isEmpty) {
      final safeError = mapFundraisingSafeError(_error!);
      return FundraisingErrorView(
        title: fundraisingErrorTitle(safeError),
        message: fundraisingErrorDescription(safeError),
        icon: _errorIconFor(safeError),
        onRetry: () => _refresh(reset: true),
      );
    }

    if (_items.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _FeedViewSwitcher(
              currentView: query.view,
              onChanged: (value) => ref
                  .read(fundraisingFeedQueryProvider.notifier)
                  .setView(value),
            ),
          ),
          Expanded(
            child: FundraisingEmptyState(
              icon: hasCustomFilters
                  ? Icons.filter_alt_off_rounded
                  : Icons.volunteer_activism_outlined,
              title: hasCustomFilters
                  ? 'No matching fundraisers'
                  : query.view == FundraisingFeedView.myFundraisers
                  ? 'No fundraisers yet'
                  : 'No public fundraisers right now',
              message: hasCustomFilters
                  ? 'Try clearing one or more filters to see available fundraisers.'
                  : query.view == FundraisingFeedView.myFundraisers
                  ? 'Drafts, submitted campaigns, and published campaigns you own will appear here.'
                  : 'Public fundraisers open for community support will appear here, including eligible campaigns under review.',
              actionLabel: hasCustomFilters
                  ? 'Clear filters'
                  : 'Create fundraiser',
              actionIcon: hasCustomFilters
                  ? Icons.filter_alt_off_rounded
                  : Icons.add_rounded,
              onAction: hasCustomFilters
                  ? () => ref
                        .read(fundraisingFeedQueryProvider.notifier)
                        .clearAll()
                  : _openCreate,
            ),
          ),
        ],
      );
    }

    final headerCount = 1 + (hasCustomFilters ? 1 : 0);
    final totalCount = _items.length + headerCount + 1;
    return RefreshIndicator(
      onRefresh: () => _refresh(reset: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: totalCount,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _FeedViewSwitcher(
              currentView: query.view,
              onChanged: (value) => ref
                  .read(fundraisingFeedQueryProvider.notifier)
                  .setView(value),
            );
          }
          if (hasCustomFilters && index == 1) {
            return _ActiveFiltersSummary(
              chips: _activeFilterChips(query),
              onClear: () =>
                  ref.read(fundraisingFeedQueryProvider.notifier).clearAll(),
            );
          }
          final itemOffset = headerCount;
          final footerIndex = itemOffset + _items.length;
          if (index < footerIndex) {
            final campaign = _items[index - itemOffset];
            if (query.view == FundraisingFeedView.myFundraisers) {
              return _MyFundraiserCard(
                campaign: campaign,
                busy: _busyCampaignActions.contains(campaign.id),
                onView: () => _openDetails(campaign.id),
                onEdit: _canEditCampaign(campaign)
                    ? () => _openEdit(campaign.id)
                    : null,
              );
            }
            return FundraisingCard(
              campaign: campaign,
              onTap: () => _openDetails(campaign.id),
            );
          }
          if (_loadingMore || _refreshing) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_error != null) {
            return Center(
              child: TextButton.icon(
                onPressed: () => _refresh(
                  reset: (_lastQuery == null || _lastQuery != query),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  _nextCursor == null ? 'Retry' : 'Retry loading more',
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Future<void> _openDetails(int campaignId) async {
    final callback = widget.onOpenDetails;
    if (callback != null) {
      callback(campaignId);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FundraisingDetailsScreen(campaignId: campaignId),
      ),
    );
    if (mounted) {
      unawaited(_refresh(reset: true));
    }
  }

  Future<void> _openEdit(int campaignId) async {
    if (_busyCampaignActions.contains(campaignId)) return;
    setState(() => _busyCampaignActions.add(campaignId));
    try {
      final callback = widget.onOpenEdit;
      final didChange = callback != null
          ? await callback(campaignId)
          : await _openCanonicalEditor(campaignId);
      if (didChange == true && mounted) {
        await _refresh(reset: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busyCampaignActions.remove(campaignId));
      }
    }
  }

  void _openCreate() {
    final callback = widget.onOpenCreate;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FundraisingCreateScreen()));
  }

  Future<bool?> _openCanonicalEditor(int campaignId) async {
    final repo = ref.read(fundraisingRepositoryProvider);
    final campaign = await repo.fetchCampaign(campaignId);
    if (!mounted) return false;
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FundraisingEditScreen(campaign: campaign),
      ),
    );
  }

  void _activateMyFundraisers() {
    widget.onOpenMyFundraisers?.call();
    ref
        .read(fundraisingFeedQueryProvider.notifier)
        .setView(FundraisingFeedView.myFundraisers);
  }

  IconData _errorIconFor(FundraisingSafeError safeError) {
    if (safeError.isNetwork) return Icons.wifi_off_rounded;
    if (safeError.isSessionExpired) return Icons.lock_clock_outlined;
    if (safeError.isPermissionDenied) return Icons.lock_outline_rounded;
    return Icons.volunteer_activism_outlined;
  }

  List<String> _activeFilterChips(FundraisingFeedQuery query) {
    final chips = <String>[_sortLabel(query.sort)];
    if (query.verified != null) {
      chips.add(query.verified == true ? 'Verified only' : 'Not verified');
    }
    if ((query.category ?? '').isNotEmpty) {
      chips.add(
        _labelFor(_categoryOptions, query.category!) ?? query.category!,
      );
    }
    if ((query.beneficiaryType ?? '').isNotEmpty) {
      chips.add(
        _labelFor(_beneficiaryOptions, query.beneficiaryType!) ??
            query.beneficiaryType!,
      );
    }
    if ((query.urgency ?? '').isNotEmpty) {
      chips.add(_labelFor(_urgencyOptions, query.urgency!) ?? query.urgency!);
    }
    if ((query.status ?? '').isNotEmpty) {
      chips.add(_labelFor(_myStatusOptions, query.status!) ?? query.status!);
    }
    if ((query.location ?? '').isNotEmpty) {
      chips.add(query.location!);
    }
    return chips;
  }

  bool _hasCustomFilters(FundraisingFeedQuery query) {
    return query.verified != null ||
        (query.category ?? '').isNotEmpty ||
        (query.beneficiaryType ?? '').isNotEmpty ||
        (query.urgency ?? '').isNotEmpty ||
        (query.status ?? '').isNotEmpty ||
        (query.location ?? '').isNotEmpty ||
        query.sort != FundraisingSort.endingSoon;
  }

  static String _sortLabel(FundraisingSort sort) {
    switch (sort) {
      case FundraisingSort.newest:
        return 'Newest';
      case FundraisingSort.oldest:
        return 'Oldest';
      case FundraisingSort.endingSoon:
        return 'Ending soon';
      case FundraisingSort.mostFunded:
        return 'Most funded';
    }
  }

  String? _labelFor(List<_FilterOption> options, String value) {
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return null;
  }

  bool _canEditCampaign(FundraisingCampaign campaign) {
    const blockedStatuses = <String>{
      'CANCELLED',
      'ARCHIVED',
      'REJECTED',
      'COMPLETED',
      'EXPIRED',
    };
    return !blockedStatuses.contains(campaign.status.trim().toUpperCase());
  }

  void _openFilters(BuildContext context) {
    final notifier = ref.read(fundraisingFeedQueryProvider.notifier);
    final query = ref.read(fundraisingFeedQueryProvider);
    final locationController = TextEditingController(
      text: query.location ?? '',
    );
    String? category = query.category;
    String? beneficiaryType = query.beneficiaryType;
    String? urgency = query.urgency;
    String? status = query.status;
    bool? verified = query.verified;
    FundraisingSort sort = query.sort;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (sheetContext, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Filter fundraisers',
                          style: Theme.of(sheetContext).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            notifier.clearAll();
                            Navigator.of(sheetContext).pop();
                          },
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<FundraisingSort>(
                      initialValue: sort,
                      decoration: const InputDecoration(
                        labelText: 'Sort by',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: FundraisingSort.endingSoon,
                          child: Text('Ending soon'),
                        ),
                        DropdownMenuItem(
                          value: FundraisingSort.newest,
                          child: Text('Newest'),
                        ),
                        DropdownMenuItem(
                          value: FundraisingSort.oldest,
                          child: Text('Oldest'),
                        ),
                        DropdownMenuItem(
                          value: FundraisingSort.mostFunded,
                          child: Text('Most funded'),
                        ),
                      ],
                      onChanged: (value) =>
                          setModalState(() => sort = value ?? sort),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<bool?>(
                      initialValue: verified,
                      decoration: const InputDecoration(
                        labelText: 'Verification',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All')),
                        DropdownMenuItem(
                          value: true,
                          child: Text('Verified only'),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text('Not verified'),
                        ),
                      ],
                      onChanged: (value) =>
                          setModalState(() => verified = value),
                    ),
                    const SizedBox(height: 12),
                    _FilterDropdown(
                      label: 'Category',
                      value: category,
                      options: _categoryOptions,
                      onChanged: (value) =>
                          setModalState(() => category = value),
                    ),
                    const SizedBox(height: 12),
                    _FilterDropdown(
                      label: 'Beneficiary',
                      value: beneficiaryType,
                      options: _beneficiaryOptions,
                      onChanged: (value) =>
                          setModalState(() => beneficiaryType = value),
                    ),
                    const SizedBox(height: 12),
                    _FilterDropdown(
                      label: 'Urgency',
                      value: urgency,
                      options: _urgencyOptions,
                      onChanged: (value) =>
                          setModalState(() => urgency = value),
                    ),
                    if (query.view == FundraisingFeedView.myFundraisers) ...[
                      const SizedBox(height: 12),
                      _FilterDropdown(
                        label: 'Campaign status',
                        value: status,
                        options: _myStatusOptions,
                        onChanged: (value) =>
                            setModalState(() => status = value),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Location or area',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () {
                          notifier.setSort(sort);
                          notifier.setVerified(verified);
                          notifier.setCategory(category);
                          notifier.setBeneficiaryType(beneficiaryType);
                          notifier.setUrgency(urgency);
                          notifier.setStatus(
                            query.view == FundraisingFeedView.myFundraisers
                                ? status
                                : null,
                          );
                          final location = locationController.text.trim();
                          notifier.setLocation(
                            location.isEmpty ? null : location,
                          );
                          Navigator.of(sheetContext).pop();
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Apply filters'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(locationController.dispose);
  }
}

class _FeedViewSwitcher extends StatelessWidget {
  const _FeedViewSwitcher({required this.currentView, required this.onChanged});

  final FundraisingFeedView currentView;
  final ValueChanged<FundraisingFeedView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Fundraiser view',
      child: SegmentedButton<FundraisingFeedView>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<FundraisingFeedView>(
            value: FundraisingFeedView.publicFeed,
            label: Text('Public'),
            icon: Icon(Icons.public_rounded),
          ),
          ButtonSegment<FundraisingFeedView>(
            value: FundraisingFeedView.myFundraisers,
            label: Text('My fundraisers'),
            icon: Icon(Icons.folder_shared_outlined),
          ),
        ],
        selected: <FundraisingFeedView>{currentView},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _MyFundraiserCard extends StatelessWidget {
  const _MyFundraiserCard({
    required this.campaign,
    required this.busy,
    required this.onView,
    this.onEdit,
  });

  final FundraisingCampaign campaign;
  final bool busy;
  final VoidCallback onView;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final status = campaign.status.trim().toUpperCase();
    final primaryLabel = status == 'DRAFT' ? 'Continue draft' : 'Edit';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FundraisingCard(campaign: campaign, onTap: onView),
        const SizedBox(height: 8),
        Semantics(
          label: 'Fundraiser actions for ${campaign.title}',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flag_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Status: ${_ownerStatusLabel(campaign.status)}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy ? null : onView,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('View'),
                      ),
                      if (onEdit != null)
                        FilledButton.icon(
                          onPressed: busy ? null : onEdit,
                          icon: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Icon(
                                  status == 'DRAFT'
                                      ? Icons.playlist_add_check_circle_outlined
                                      : Icons.edit_outlined,
                                ),
                          label: Text(primaryLabel),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _ownerStatusLabel(String raw) {
  final words = raw
      .trim()
      .toLowerCase()
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}');
  return words.isEmpty ? 'Unknown' : words.join(' ');
}

class _ActiveFiltersSummary extends StatelessWidget {
  const _ActiveFiltersSummary({required this.chips, required this.onClear});

  final List<String> chips;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Active filters',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(onPressed: onClear, child: const Text('Clear all')),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in chips)
                  Chip(label: Text(chip), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<_FilterOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All')),
        ...options.map(
          (option) => DropdownMenuItem<String?>(
            value: option.value,
            child: Text(option.label),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _FilterOption {
  const _FilterOption({required this.value, required this.label});

  final String value;
  final String label;
}
