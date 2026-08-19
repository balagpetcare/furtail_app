import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/search_service.dart';
import '../providers/search_providers.dart';
import 'package:furtail_app/app/router/app_routes.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late TabController _tabController;
  String _currentQuery = '';
  int _searchToken = 0;

  bool _isLoading = false;
  String? _error;
  SearchAllPage? _allResults;
  SearchResultPage? _peopleResults;
  SearchResultPage? _postsResults;
  SearchResultPage? _petsResults;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_currentQuery.trim().length >= 2) {
      _performSearch(_currentQuery);
    }
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.length < 2 || _isLoading) return;
    setState(() {
      _currentQuery = query;
    });
    _performSearch(query);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentQuery = '';
      _allResults = null;
      _peopleResults = null;
      _postsResults = null;
      _petsResults = null;
      _error = null;
      _isLoading = false;
    });
  }

  String _getCurrentTabType() {
    switch (_tabController.index) {
      case 0:
        return 'all';
      case 1:
        return 'people';
      case 2:
        return 'posts';
      case 3:
        return 'pets';
      default:
        return 'all';
    }
  }

  Future<void> _performSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) {
      setState(() {
        _allResults = null;
        _peopleResults = null;
        _postsResults = null;
        _petsResults = null;
        _error = null;
        _isLoading = false;
      });
      return;
    }

    final token = ++_searchToken;
    final type = _getCurrentTabType();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(searchServiceProvider);
      final result = await service.search(query: trimmedQuery, type: type);

      if (mounted && _searchToken == token) {
        setState(() {
          _isLoading = false;
          if (type == 'all') {
            _allResults = result as SearchAllPage;
          } else if (type == 'people') {
            _peopleResults = result as SearchResultPage;
          } else if (type == 'posts') {
            _postsResults = result as SearchResultPage;
          } else if (type == 'pets') {
            _petsResults = result as SearchResultPage;
          }
        });
      }
    } catch (e) {
      if (mounted && _searchToken == token) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load results.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    final appBarColor = cs.primary;
    const elementsColor = Colors.white;
    const hintColor = Colors.white70;

    final bool canSearch = _searchController.text.trim().length >= 2;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: elementsColor,
        elevation: 0,
        leading: const BackButton(color: elementsColor),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submitSearch(),
                    style: context.appText.bodyLarge?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: Colors.black87,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search Furtail...',
                      hintStyle: context.appText.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              onPressed: _clearSearch,
                              splashRadius: 20,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: (_isLoading || !canSearch) ? null : _submitSearch,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: cs.primary,
                    disabledBackgroundColor: Colors.white.withOpacity(0.5),
                    disabledForegroundColor: cs.primary.withOpacity(0.5),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        )
                      : const Text(
                          'Search',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: elementsColor,
          unselectedLabelColor: hintColor,
          indicatorColor: elementsColor,
          indicatorWeight: 3,
          labelStyle: context.appText.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: context.appText.titleSmall,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'People'),
            Tab(text: 'Posts'),
            Tab(text: 'Pets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllTab(),
          _buildPeopleTab(),
          _buildPostsTab(),
          _buildPetsTab(),
        ],
      ),
    );
  }

  Widget _buildState(Widget Function() builder) {
    if (_currentQuery.trim().length < 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 64,
              color: context.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Type at least 2 characters to search',
              style: context.appText.bodyLarge?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: context.colorScheme.error.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: context.appText.titleMedium?.copyWith(
                  color: context.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _performSearch(_currentQuery),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return builder();
  }

  Widget _buildEmptyResults(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: context.appText.bodyLarge?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllTab() {
    return _buildState(() {
      if (_allResults == null) return const SizedBox.shrink();
      final hasAny =
          _allResults!.people.items.isNotEmpty ||
          _allResults!.posts.items.isNotEmpty ||
          _allResults!.pets.items.isNotEmpty;
      if (!hasAny)
        return _buildEmptyResults('No results found for "$_currentQuery"');

      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          if (_allResults!.people.items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'People',
                style: context.appText.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.primary,
                ),
              ),
            ),
            ..._allResults!.people.items.map((i) => _buildPersonTile(i)),
            const Divider(height: 32),
          ],
          if (_allResults!.posts.items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Posts',
                style: context.appText.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.primary,
                ),
              ),
            ),
            ..._allResults!.posts.items.map((i) => _buildPostTile(i)),
            const Divider(height: 32),
          ],
          if (_allResults!.pets.items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Pets',
                style: context.appText.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.primary,
                ),
              ),
            ),
            ..._allResults!.pets.items.map((i) => _buildPetTile(i)),
          ],
        ],
      );
    });
  }

  Widget _buildPeopleTab() {
    return _buildState(() {
      if (_peopleResults == null) return const SizedBox.shrink();
      if (_peopleResults!.items.isEmpty)
        return _buildEmptyResults('No people found');
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _peopleResults!.items.length,
        itemBuilder: (context, index) =>
            _buildPersonTile(_peopleResults!.items[index]),
      );
    });
  }

  Widget _buildPostsTab() {
    return _buildState(() {
      if (_postsResults == null) return const SizedBox.shrink();
      if (_postsResults!.items.isEmpty)
        return _buildEmptyResults('No posts found');
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _postsResults!.items.length,
        itemBuilder: (context, index) =>
            _buildPostTile(_postsResults!.items[index]),
      );
    });
  }

  Widget _buildPetsTab() {
    return _buildState(() {
      if (_petsResults == null) return const SizedBox.shrink();
      if (_petsResults!.items.isEmpty)
        return _buildEmptyResults('No pets found');
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _petsResults!.items.length,
        itemBuilder: (context, index) =>
            _buildPetTile(_petsResults!.items[index]),
      );
    });
  }

  Widget _buildPersonTile(dynamic item) {
    return ListTile(
      onTap: () {
        final id = item['id'];
        if (id != null) {
          Navigator.pushNamed(
            context,
            AppRoutes.visitorProfile,
            arguments: {'userId': id},
          );
        }
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: item['avatarUrl'] != null
            ? NetworkImage(item['avatarUrl'])
            : null,
        backgroundColor: context.colorScheme.surfaceContainerHighest,
        child: item['avatarUrl'] == null
            ? Icon(Icons.person, color: context.colorScheme.onSurfaceVariant)
            : null,
      ),
      title: Text(
        item['displayName'] ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        item['username'] != null ? '@${item['username']}' : '',
        style: TextStyle(color: context.colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildPostTile(dynamic item) {
    final author = item['author'] ?? {};
    return ListTile(
      onTap: () {
        try {
          final post = PostModel.fromJson(item as Map<String, dynamic>);
          Navigator.pushNamed(
            context,
            AppRoutes.postDetails,
            arguments: {'post': post},
          );
        } catch (e) {
          // Fallback if parsing fails
        }
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: author['avatarUrl'] != null
            ? NetworkImage(author['avatarUrl'])
            : null,
        backgroundColor: context.colorScheme.surfaceContainerHighest,
        child: author['avatarUrl'] == null
            ? Icon(Icons.person, color: context.colorScheme.onSurfaceVariant)
            : null,
      ),
      title: Text(
        author['displayName'] ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        item['snippet'] ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: item['mediaUrl'] != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: FurtailCachedImage(
                  imageUrl: item['mediaUrl'],
                  fit: BoxFit.cover,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPetTile(dynamic item) {
    final owner = item['owner'] ?? {};
    return ListTile(
      onTap: () {
        final id = item['id'];
        if (id != null) {
          Navigator.pushNamed(
            context,
            AppRoutes.petPublicProfile,
            arguments: {'petId': id},
          );
        }
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: item['photoUrl'] != null
            ? NetworkImage(item['photoUrl'])
            : null,
        backgroundColor: context.colorScheme.surfaceContainerHighest,
        child: item['photoUrl'] == null
            ? Icon(Icons.pets, color: context.colorScheme.onSurfaceVariant)
            : null,
      ),
      title: Text(
        item['name'] ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${item['breedName'] ?? 'Unknown'} • Owner: ${owner['displayName'] ?? 'Unknown'}',
        style: TextStyle(color: context.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
