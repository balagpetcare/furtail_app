import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/data/services/feed_cache_service.dart';
import 'package:furtail_app/features/home/presentation/widgets/feed/feed_post_card.dart';

// TODO(Phase 2): Replace FeedCacheService with a Drift/Isar query here so
// the feed list can load incrementally from the local DB rather than
// parsing the entire JSON blob at once.

// =============================
// HOME FEED (posts only) â€” offline-first
// =============================

class FeedList extends StatefulWidget {
  /// If you already have current user id from parent, pass it.
  /// Otherwise FeedList will load it from SharedPreferences('userId').
  final int? meId;

  /// Changing this token forces FeedList to refetch from the network.
  final Object? refreshToken;

  /// Callback when the feed decides a parent-level refresh is needed.
  final VoidCallback? onNeedRefresh;

  const FeedList({super.key, this.meId, this.refreshToken, this.onNeedRefresh});

  @override
  State<FeedList> createState() => _FeedListState();
}

class _FeedListState extends State<FeedList> {
  final _ds = PostsRemoteDs();
  final _cache = FeedCacheService();

  /// Posts currently displayed. Never cleared to empty if valid cache exists.
  List<PostModel> _posts = const [];

  /// True while the posts shown are from cache, not a fresh network response.
  bool _isFromCache = false;

  /// True when a network request is in-flight.
  bool _isLoadingFromNetwork = false;

  /// Last network error. Cleared on successful fetch.
  String? _networkError;

  /// Timestamp of the data in [_posts] (either cache age or fetch time).
  DateTime? _dataAge;

  int? _meId;

  // â”€â”€ Debug build counter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  int _buildCount = 0;

  @override
  void initState() {
    super.initState();
    _meId = widget.meId;
    if (_meId == null) _loadMe();
    _loadCacheThenFetch();
  }

  Future<void> _loadMe() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final id = sp.getInt('userId');
      if (!mounted) return;
      setState(() => _meId = id);
    } catch (_) {}
  }

  // â”€â”€ Cache-then-network strategy â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //
  // Display flow:
  //   1. Load cache â†’ show immediately (zero network cost, any age).
  //   2. Fetch from network â†’ replace cache display on success.
  //   3. On network failure â†’ keep showing cache; show error notice.
  //
  // The TTL in FeedCacheService is only consulted to decide how the loading
  // indicator looks, not whether to show the cache.

  Future<void> _loadCacheThenFetch() async {
    // Step 1: Paint the cached posts before touching the network.
    final cached = await _cache.loadFeed();
    final cachedAt = await _cache.lastFetchedAt();

    if (mounted && cached != null) {
      // Show whatever is in cache â€“ even an empty list is valid state.
      // Do NOT require cached.isNotEmpty; an empty cached result is still
      // "we have a cache" and should suppress the loading spinner.
      setState(() {
        _posts = cached;
        _isFromCache = cached.isNotEmpty;
        _dataAge = cachedAt;
      });
    }

    // Step 2: Always try the network for fresh data.
    await _fetchFromNetwork();
  }

  Future<void> _fetchFromNetwork() async {
    if (!mounted) return;
    // Deduplicate: don't start a second network request while one is running.
    if (_isLoadingFromNetwork) return;
    setState(() => _isLoadingFromNetwork = true);

    try {
      final posts = await _ds.getFeed(limit: 50);
      if (!mounted) return;

      // Guard: if the fresh response is empty but we had cached posts, keep
      // the cached posts rather than replacing with an empty screen.
      // An empty server response on a fresh install is shown normally.
      final hadCachedContent = _isFromCache && _posts.isNotEmpty;
      final freshIsEmpty = posts.isEmpty;

      setState(() {
        _posts = (freshIsEmpty && hadCachedContent) ? _posts : posts;
        _isFromCache = freshIsEmpty && hadCachedContent;
        _dataAge = DateTime.now();
        _isLoadingFromNetwork = false;
        _networkError = null;
      });
    } on SocketException catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingFromNetwork = false;
        _networkError = 'offline';
        // _posts and _isFromCache intentionally not changed â€“ keep cached data.
      });
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingFromNetwork = false;
        _networkError = 'timeout';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingFromNetwork = false;
        _networkError = e.toString();
      });
    }
  }

  @override
  void didUpdateWidget(covariant FeedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meId != widget.meId && widget.meId != null) {
      _meId = widget.meId;
    }
    // Parent increments refreshToken to trigger a network refetch (e.g., when
    // internet comes back or the user pulls-to-refresh).
    if (oldWidget.refreshToken != widget.refreshToken) {
      _fetchFromNetwork();
    }
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //
  // IMPORTANT: Returns a *sliver* widget (SliverToBoxAdapter or SliverList) so
  // it can be inserted directly into CustomScrollView.slivers.
  //
  // The normal path returns SliverList with SliverChildBuilderDelegate which
  // renders items lazily â€” only the items scrolled into view are built.
  // This replaces the previous shrinkWrap ListView which forced all 50 posts
  // to be laid out synchronously, causing scroll jank on mid-range devices.

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    if (kDebugMode && _buildCount % 5 == 1) {
      debugPrint('[FeedList] build #$_buildCount  posts=${_posts.length}');
    }

    // Show full-screen spinner ONLY when there is truly nothing to show yet.
    if (_isLoadingFromNetwork && _posts.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Show error state only when there is NO cached fallback.
    if (_posts.isEmpty && _networkError != null) {
      return SliverToBoxAdapter(child: _buildErrorState(_networkError!));
    }

    // Truly empty: no cache, no posts, no error (e.g., fresh install + logged out).
    if (_posts.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final showNotice = _isFromCache || _networkError != null;

    // Header items that appear before the post list in the sliver.
    final headerCount = showNotice ? 1 : 0;
    final totalCount = headerCount + _posts.length;

    // SliverList with SliverChildBuilderDelegate gives true lazy rendering:
    // each post card is built only when it scrolls into view.
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // â”€â”€ Header items â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (index < headerCount) {
            int h = index;
            if (showNotice) {
              if (h == 0) {
                return _CachedFeedNotice(
                  dataAge: _dataAge,
                  isNetworkError: _networkError != null,
                  isRefreshing: _isLoadingFromNetwork,
                );
              }
              h--;
            }
          }

          // â”€â”€ Post items â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          final postIndex = index - headerCount;
          final post = _posts[postIndex];
          return Padding(
            // Replicate the 12px separator the old ListView.separated used.
            padding: EdgeInsets.only(bottom: 12, top: postIndex == 0 ? 0 : 0),
            child: RepaintBoundary(
              child: PostCard(
                key: ValueKey(post.id),
                post: post,
                meId: _meId,
                onNeedRefresh: _fetchFromNetwork,
              ),
            ),
          );
        },
        childCount: totalCount,
        // Stable key for list identity â€” helps Flutter reuse element subtrees
        // when setState is called (e.g., on feed refresh).
        findChildIndexCallback: (key) {
          if (key is ValueKey<int>) {
            final idx = _posts.indexWhere((p) => p.id == key.value);
            if (idx == -1) return null;
            return headerCount + idx;
          }
          return null;
        },
      ),
    );
  }

  Widget _buildErrorState(String err) {
    final isAuthError =
        err.contains('401') ||
        err.toLowerCase().contains('no token') ||
        err.toLowerCase().contains('unauthorized');

    if (isAuthError) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6E6E6)),
          ),
          child: const Text(
            'Please log in to view the home feed\nYou will see photo posts, videos, and text posts here.',
            style: TextStyle(height: 1.4),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6E6E6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Feed load failed: $err'),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _fetchFromNetwork,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Cached-feed notice bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CachedFeedNotice extends StatelessWidget {
  final DateTime? dataAge;
  final bool isNetworkError;
  final bool isRefreshing;

  const _CachedFeedNotice({
    required this.dataAge,
    required this.isNetworkError,
    required this.isRefreshing,
  });

  String get _ageText {
    if (dataAge == null) return 'Cached content';
    final diff = DateTime.now().difference(dataAge!);
    if (diff.inMinutes < 1) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    return 'Updated ${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isNetworkError
            ? const Color(0xFFFFF3E0)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isNetworkError
              ? const Color(0xFFFFCC80)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          if (isRefreshing)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else
            Icon(
              isNetworkError ? Icons.cloud_off_outlined : Icons.history_rounded,
              size: 14,
              color: isNetworkError
                  ? const Color(0xFFE65100)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              isRefreshing
                  ? 'Refreshing...'
                  : isNetworkError
                  ? 'Offline Â· $_ageText'
                  : _ageText,
              style: TextStyle(
                fontSize: 11,
                color: isNetworkError
                    ? const Color(0xFFE65100)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
