import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/home/presentation/widgets/feed/feed_post_card.dart';

/// Simple profile posts tab (client-side filter from feed).
/// Now backed by: GET /posts/user/:userId
class ProfileTabPosts extends StatefulWidget {
  final int userId;
  const ProfileTabPosts({super.key, required this.userId});

  @override
  State<ProfileTabPosts> createState() => _ProfileTabPostsState();
}

class _ProfileTabPostsState extends State<ProfileTabPosts> {
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final mine = await _ds.getUserFeed(userId: widget.userId, limit: 50);
      if (!mounted) return;
      setState(() {
        _items = mine;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No posts yet.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final p = _items[index];
          return PostCard(post: p, meId: _meId, onNeedRefresh: _load);
        },
      ),
    );
  }
}
