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
// HOME FEED (posts only) — offline-first
// =============================

class FeedList extends StatefulWidget {
  /// If you already have current user id from parent, pass it.
  /// Otherwise FeedList will load it from SharedPreferences('userId').
  final int? meId;

  /// Changing this token forces FeedList to refetch from the network.
  final Object? refreshToken;

  /// Callback when the feed decides a parent-level refresh is needed.
  final VoidCallback? onNeedRefresh;

  const FeedList({
    super.key,
    this.meId,
    this.refreshToken,
    this.onNeedRefresh,
  });

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

  int? _meId;

  // ── Debug build counter ────────────────────────────────────────────────
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

  // ── Cache-then-network strategy ────────────────────────────────────────
  //
  // Display flow:
  //   1. Load cache → show immediately (zero network cost, any age).
  //   2. Fetch from network → replace cache display on success.
  //   3. On network failure → keep showing cache; show error notice.
  //
  // The TTL in FeedCacheService is only consulted to decide how the loading
  // indicator looks, not whether to show the cache.

  Future<void> _loadCacheThenFetch() async {
    // Step 1: Paint the cached posts before touching the network.
    final cached = await _cache.loadFeed();
    if (mounted && cached != null) {
      setState(() {
        _posts = cached;
        _isFromCache = cached.isNotEmpty;
      });
    }

    // Step 2: Always try the network for fresh data.
    await _fetchFromNetwork();
  }

  Future<void> _fetchFromNetwork() async {
    if (!mounted) return;
    if (_isLoadingFromNetwork) return;
    setState(() => _isLoadingFromNetwork = true);

    try {
      final posts = await _ds.getFeed(limit: 50);
      if (!mounted) return;

      final hadCachedContent = _isFromCache && _posts.isNotEmpty;
      final freshIsEmpty = posts.isEmpty;

      setState(() {
        _posts = (freshIsEmpty && hadCachedContent) ? _posts : posts;
        _isFromCache = freshIsEmpty && hadCachedContent;
        _isLoadingFromNetwork = false;
        _networkError = null;
      });
    } on SocketException catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingFromNetwork = false;
        _networkError = 'offline';
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
    if (oldWidget.refreshToken != widget.refreshToken) {
      _fetchFromNetwork();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

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

    // Pure post list — no banners inside the feed
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final post = _posts[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 8),
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
        childCount: _posts.length,
        findChildIndexCallback: (key) {
          if (key is ValueKey<int>) {
            final idx = _posts.indexWhere((p) => p.id == key.value);
            if (idx == -1) return null;
            return idx;
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


