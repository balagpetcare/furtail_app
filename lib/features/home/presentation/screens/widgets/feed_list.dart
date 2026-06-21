import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/home/presentation/widgets/feed/feed_reels_strip.dart';
import 'package:furtail_app/features/home/presentation/widgets/feed/feed_post_card.dart';

// =============================
// HOME FEED (posts + reels)
// =============================

class FeedList extends StatefulWidget {
  /// If you already have current user id from parent, pass it.
  /// Otherwise FeedList will load it from SharedPreferences('userId').
  final int? meId;

  /// Changing this token will force FeedList to refetch the feed.
  final Object? refreshToken;

  /// If parent wants to get notified to refresh something outside, use it.
  final VoidCallback? onNeedRefresh;

  const FeedList({super.key, this.meId, this.refreshToken, this.onNeedRefresh});

  @override
  State<FeedList> createState() => _FeedListState();
}

class _FeedListState extends State<FeedList> {
  final _ds = PostsRemoteDs();

  Future<List<PostModel>>? _future;
  int? _meId;

  @override
  void initState() {
    super.initState();
    _future = _ds.getFeed(limit: 50);

    // Prefer parent-provided meId; otherwise load from prefs.
    _meId = widget.meId;
    if (_meId == null) {
      _loadMe();
    }
  }

  Future<void> _loadMe() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final id = sp.getInt('userId'); // আপনার key যদি আলাদা হয় এখানে বদলাবেন
      if (!mounted) return;
      setState(() => _meId = id);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant FeedList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If parent now provides meId later
    if (oldWidget.meId != widget.meId && widget.meId != null) {
      _meId = widget.meId;
    }

    // Refresh feed if refreshToken changed
    if (oldWidget.refreshToken != widget.refreshToken) {
      setState(() {
        _future = _ds.getFeed(limit: 50);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<PostModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snap.hasError) {
            final err = snap.error.toString();
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
                    'Please log in to view the home feed ✅\nYou will see photo posts, reels, and text posts here.',
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
                      onPressed: () => setState(() {
                        _future = _ds.getFeed(limit: 50);
                      }),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final posts = snap.data ?? const [];
          final reels = posts.where((p) => p.isVideo).take(12).toList();

          return Column(
            children: [
              if (reels.isNotEmpty) ReelsStrip(reels: reels),
              ListView.separated(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: posts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => PostCard(
                  post: posts[i],
                  meId: _meId, // ✅ pass down
                  onNeedRefresh: () => setState(() {
                    _future = _ds.getFeed(limit: 50);
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
