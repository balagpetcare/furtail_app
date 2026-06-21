import 'package:flutter/material.dart';

import 'package:bpa_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:bpa_app/features/posts/presentation/screens/post_details_screen.dart';
import 'package:bpa_app/features/posts/data/models/post_model.dart';
import 'package:bpa_app/app/router/app_routes.dart';

class ProfileTabGallery extends StatefulWidget {
  final int userId;
  final bool canManage;
  const ProfileTabGallery({super.key, required this.userId, this.canManage = false});

  @override
  State<ProfileTabGallery> createState() => _ProfileTabGalleryState();
}

class _ProfileTabGalleryState extends State<ProfileTabGallery> {
  final _ds = PostsRemoteDs();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String? _nextCursor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = !more;
      _error = null;
    });
    try {
      final data = await _ds.getUserPhotoGallery(
        userId: widget.userId,
        limit: 50,
        cursor: more ? _nextCursor : null,
      );

      final items = (data['items'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      final next = data['nextCursor']?.toString();

      setState(() {
        if (more) {
          _items.addAll(items);
        } else {
          _items = items;
        }
        _nextCursor = (next == null || next.isEmpty) ? null : next;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openPost(int postId) async {
    try {
      final PostModel post = await _ds.getPostById(postId: postId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailsScreen(post: post)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _openActions({required int postId}) async {
    if (!widget.canManage) {
      await _openPost(postId);
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open post'),
                onTap: () async {
                  Navigator.pop(context);
                  await _openPost(postId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final post = await _ds.getPostById(postId: postId);
                    if (!mounted) return;
                    final updated = await Navigator.pushNamed(
                      context,
                      AppRoutes.postEdit,
                      arguments: {'post': post},
                    );
                    if (updated != null) {
                      await _load();
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                    );
                  }
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
                      content: const Text('This will remove the post from your gallery.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  try {
                    await _ds.deletePost(postId: postId);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deleted ✅')),
                    );
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
        );
      },
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
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    final items = _items;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GridView.builder(
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, i) {
                final it = items[i];
                final url = (it['url'] ?? '').toString();
                final postId = (it['postId'] as num?)?.toInt() ?? 0;
                return InkWell(
                  onTap: postId > 0 ? () => _openPost(postId) : null,
                  onLongPress: (postId > 0) ? () => _openActions(postId: postId) : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(url, fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: _nextCursor == null ? null : () => _load(more: true),
              child: Text(_nextCursor == null ? 'No more' : 'View more'),
            ),
          ),
        ],
      ),
    );
  }
}
