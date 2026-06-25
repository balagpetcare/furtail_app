import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/home/presentation/widgets/feed/feed_post_card.dart';
import 'package:furtail_app/core/theme/typography.dart';

/// Screen to view saved/bookmarked posts.
class SavedPostsScreen extends StatelessWidget {
  const SavedPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Saved Posts'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: const SafeArea(
        child: SavedPostsList(),
      ),
    );
  }
}

/// Reusable widget to display the logged-in user's saved/bookmarked posts.
class SavedPostsList extends StatefulWidget {
  const SavedPostsList({super.key});

  @override
  State<SavedPostsList> createState() => _SavedPostsListState();
}

class _SavedPostsListState extends State<SavedPostsList> {
  final _ds = PostsRemoteDs();
  bool _loading = true;
  String? _error;
  List<PostModel> _items = const [];
  int? _meId;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _load();
  }

  Future<void> _loadMe() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _meId = sp.getInt('userId');
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _ds.getBookmarkedPosts(limit: 50);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Failed to load saved posts',
                style: context.appText.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyRegular(context, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bookmark_border_rounded,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No saved posts yet',
                style: context.appText.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Post bookmarks will show up here for easy access.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyRegular(context, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final p = _items[index];
          return PostCard(
            post: p,
            meId: _meId,
            onNeedRefresh: _load,
          );
        },
      ),
    );
  }
}
