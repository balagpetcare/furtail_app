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
  });

  final FundraisingFeedPageLoader? pageLoader;
  final bool autoLoad;

  @override
  ConsumerState<FundraisingFeedScreen> createState() =>
      _FundraisingFeedScreenState();
}

class _FundraisingFeedScreenState extends ConsumerState<FundraisingFeedScreen> {
  final List<FundraisingCampaign> _items = <FundraisingCampaign>[];
  final ScrollController _scrollController = ScrollController();

  bool _initialLoading = false;
  bool _refreshing = false;
  bool _loadingMore = false;
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
    return repo.fetchFeedPage(
      limit: 20,
      cursor: cursor,
      verified: query.verified,
      category: query.category,
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
      title: 'Fundraising',
      showBack: true,
      showDonationHistory: true,
      showWithdrawHub: true,
      showFilters: true,
      showVerification: true,
      showCreate: true,
      onOpenFilters: () => _openFilters(context),
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
        icon: safeError.isNetwork
            ? Icons.wifi_off_rounded
            : Icons.volunteer_activism_outlined,
        onRetry: () => _refresh(reset: true),
      );
    }

    if (_items.isEmpty) {
      return FundraisingEmptyState(
        icon: hasCustomFilters
            ? Icons.filter_alt_off_rounded
            : Icons.volunteer_activism_outlined,
        title: hasCustomFilters
            ? 'No matching fundraisers'
            : 'No fundraisers yet',
        message: hasCustomFilters
            ? 'Try clearing one or more filters to see available fundraisers.'
            : 'Published fundraisers will appear here as soon as they are available.',
        actionLabel: hasCustomFilters ? 'Clear filters' : 'Create fundraiser',
        actionIcon: hasCustomFilters
            ? Icons.filter_alt_off_rounded
            : Icons.add_rounded,
        onAction: hasCustomFilters
            ? () => ref.read(fundraisingFeedQueryProvider.notifier).clearAll()
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FundraisingCreateScreen(),
                ),
              ),
      );
    }

    final totalCount = _items.length + (hasCustomFilters ? 1 : 0) + 1;
    return RefreshIndicator(
      onRefresh: () => _refresh(reset: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: totalCount,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (hasCustomFilters && index == 0) {
            return _ActiveFiltersSummary(
              summary: _querySummary(query),
              onClear: () =>
                  ref.read(fundraisingFeedQueryProvider.notifier).clearAll(),
            );
          }
          final itemOffset = hasCustomFilters ? 1 : 0;
          final footerIndex = itemOffset + _items.length;
          if (index < footerIndex) {
            final campaign = _items[index - itemOffset];
            return FundraisingCard(
              campaign: campaign,
              onTap: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) =>
                          FundraisingDetailsScreen(campaignId: campaign.id),
                    ),
                  )
                  .then((_) => _refresh(reset: true)),
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

  static String _querySummary(FundraisingFeedQuery query) {
    final parts = <String>[_sortLabel(query.sort)];
    if (query.verified != null) {
      parts.add(query.verified == true ? 'Verified' : 'Not verified');
    }
    if ((query.category ?? '').isNotEmpty) parts.add(query.category!);
    if ((query.location ?? '').isNotEmpty) parts.add(query.location!);
    return parts.join(' • ');
  }

  static bool _hasCustomFilters(FundraisingFeedQuery query) {
    return query.verified != null ||
        (query.category ?? '').isNotEmpty ||
        (query.location ?? '').isNotEmpty ||
        query.sort != FundraisingSort.endingSoon;
  }

  static String _sortLabel(FundraisingSort sort) {
    switch (sort) {
      case FundraisingSort.newCampaigns:
        return 'Newest';
      case FundraisingSort.topDonated:
        return 'Top donated';
      case FundraisingSort.endingSoon:
        return 'Ending soon';
    }
  }

  void _openFilters(BuildContext context) {
    final notifier = ref.read(fundraisingFeedQueryProvider.notifier);
    final query = ref.read(fundraisingFeedQueryProvider);
    final locationController = TextEditingController(
      text: query.location ?? '',
    );
    String? category = query.category;
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
                          child: const Text('Reset'),
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
                          value: FundraisingSort.newCampaigns,
                          child: Text('Newest'),
                        ),
                        DropdownMenuItem(
                          value: FundraisingSort.topDonated,
                          child: Text('Top donated'),
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
                    DropdownButtonFormField<String?>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All')),
                        DropdownMenuItem(
                          value: 'Treatment',
                          child: Text('Treatment'),
                        ),
                        DropdownMenuItem(value: 'Food', child: Text('Food')),
                        DropdownMenuItem(
                          value: 'Shelter',
                          child: Text('Shelter'),
                        ),
                        DropdownMenuItem(
                          value: 'Vaccination',
                          child: Text('Vaccination'),
                        ),
                        DropdownMenuItem(
                          value: 'Rescue',
                          child: Text('Rescue'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) =>
                          setModalState(() => category = value),
                    ),
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

class _ActiveFiltersSummary extends StatelessWidget {
  const _ActiveFiltersSummary({required this.summary, required this.onClear});

  final String summary;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Clear filters',
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
