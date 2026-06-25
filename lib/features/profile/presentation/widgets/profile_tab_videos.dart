import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter/material.dart';

import 'package:furtail_app/app/router/app_routes.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/presentation/screens/post_details_screen.dart';

class ProfileTabVideos extends StatefulWidget {
  final int userId;
  final bool canManage;

  const ProfileTabVideos({
    super.key,
    required this.userId,
    this.canManage = false,
  });

  @override
  State<ProfileTabVideos> createState() => _ProfileTabVideosState();
}

class _ProfileTabVideosState extends State<ProfileTabVideos> {
  final _ds = PostsRemoteDs();
  bool _loading = true;
  String? _error;
  List<PostModel> _videos = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final posts = await _ds.getUserFeed(userId: widget.userId, limit: 100);
      final vids = posts.where((p) => p.isVideo).toList();
      if (!mounted) return;
      setState(() {
        _videos = vids;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openPost(PostModel p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailsScreen(post: p)),
    );
  }

  Future<void> _openActions(PostModel p) async {
    if (!widget.canManage) {
      await _openPost(p);
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open post'),
              onTap: () async {
                Navigator.pop(context);
                await _openPost(p);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () async {
                Navigator.pop(context);
                final updated = await Navigator.pushNamed(
                  context,
                  AppRoutes.postEdit,
                  arguments: {'post': p},
                );
                if (updated != null) await _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(context);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete post?'),
                    content: const Text('This will remove the video post.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok != true) return;
                try {
                  await _ds.deletePost(postId: p.id);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted ✅')));
                  await _load();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'No videos yet.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text('When you post a video or reel, it will appear here.'),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _videos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final p = _videos[i];
          final thumb = p.media
              .where((m) => m.type.toUpperCase() == 'IMAGE')
              .map((m) => m.url)
              .cast<String?>()
              .firstWhere((u) => (u ?? '').isNotEmpty, orElse: () => null);

          return InkWell(
            onTap: () => _openPost(p),
            onLongPress: () => _openActions(p),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE6E6E6)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 88,
                      height: 64,
                      color: const Color(0xFFF2F2F2),
                      child: thumb == null
                          ? const Icon(Icons.play_circle_fill, size: 34)
                          : Image.network(thumb, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (p.caption ?? '').isEmpty ? 'Video post' : p.caption!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${p.likeCount} Paws · ${p.commentCount} comments',
                          style: context.appText.bodySmall!.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
