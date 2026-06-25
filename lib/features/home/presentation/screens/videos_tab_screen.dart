import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/presentation/screens/reels_player_screen.dart';

class VideosTabScreen extends StatefulWidget {
  final Object? refreshToken;

  const VideosTabScreen({super.key, this.refreshToken});

  @override
  State<VideosTabScreen> createState() => _VideosTabScreenState();
}

class _VideosTabScreenState extends State<VideosTabScreen> {
  final _ds = PostsRemoteDs();
  final List<String> _categories = const [
    'For You',
    'Following',
    'Health',
    'Training',
    'Rescue',
    'Funny',
    'Shop',
  ];

  var _selectedCategory = 0;
  var _loading = true;
  String? _error;
  List<PostModel> _videos = const [];

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void didUpdateWidget(covariant VideosTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadVideos();
    }
  }

  Future<void> _loadVideos() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final posts = await _ds.getFeed(limit: 100);
      if (!mounted) return;
      setState(() {
        _videos = posts.where((post) => post.isVideo).toList();
        _loading = false;
      });
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _error =
            'You are offline. Videos will load when the connection returns.';
        _loading = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = 'Video feed timed out. Pull to refresh and try again.';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load videos right now.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading && _videos.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_videos.isEmpty) {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: _loadVideos,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 96, 24, 120),
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                size: 56,
                color: cs.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'No videos yet',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Pet videos from your community will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ReelsPlayerScreen(reels: _videos, initialIndex: 0),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = _selectedCategory == index;
                return ChoiceChip(
                  label: Text(_categories[index]),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = index),
                  selectedColor: Colors.white,
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                  labelStyle: TextStyle(
                    color: selected ? cs.primary : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(
                    color: selected ? Colors.white : Colors.white54,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
