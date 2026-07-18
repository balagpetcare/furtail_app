import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/core/storage/local_storage.dart';
import 'package:furtail_app/features/posts/presentation/widgets/comments_sheet.dart';
import 'package:furtail_app/features/posts/presentation/screens/post_details_screen.dart';
import 'package:furtail_app/features/posts/presentation/widgets/post_action_sheet.dart';
import 'package:furtail_app/features/posts/presentation/widgets/report_bottom_sheet.dart';
import 'package:furtail_app/core/media/media_playback_controller.dart';
import 'package:furtail_app/core/media/fullscreen_video_player_screen.dart';
import 'package:furtail_app/core/media/media_url.dart';
import 'package:furtail_app/core/navigation/profile_navigation.dart';
import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/features/home/presentation/screens/furtail_home_screen.dart';
import 'package:furtail_app/features/posts/presentation/widgets/reel_action_button.dart';
import 'package:furtail_app/features/posts/presentation/widgets/reel_seek_bar.dart';
import 'package:furtail_app/core/media/furtail_cache_manager.dart';

class ReelsPlayerScreen extends StatefulWidget {
  final List<PostModel> reels;
  final int initialIndex;

  const ReelsPlayerScreen({
    super.key,
    required this.reels,
    this.initialIndex = 0,
  });

  @override
  State<ReelsPlayerScreen> createState() => _ReelsPlayerScreenState();
}

class _ReelsPlayerScreenState extends State<ReelsPlayerScreen>
    with WidgetsBindingObserver {
  // UI state for overlay controls
  bool _showControls = true;
  Timer? _hideTimer;

  // Reels: caption/text overlay is handled per-page. We keep this screen lean
  // to avoid rebuild-driven controller churn.
  final _ds = PostsRemoteDs();
  final media = MediaPlaybackController.instance;
  late final PageController _page;

  int _index = 0;
  VideoPlayerController? _vc;
  Future<void>? _init;

  int _prepareToken = 0;
  VoidCallback? _playbackListener;
  bool _wakelockHeld = false;
  int _loopCount = 0;
  String? _activeFilePath;

  late List<PostModel> _reels;
  int? _meId;
  int _selectedCategoryIndex = 0;
  String _sort = 'latest';
  String? _duration;
  bool _useFollowingOnly = false;
  String _searchQuery = '';
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _isLoadingFirstPage = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _feedError;
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _likeBusyPostIds = <int>{};

  VoidCallback? _muteListener;
  bool _detailMuted = false;

  static const List<String> _categories = [
    'For You',
    'Following',
    'Health',
    'Training',
    'Rescue',
    'Funny',
    'Shop',
  ];

  // â”€â”€ Single-video detail state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    media.ensureInitialized().then((_) {
      // Keep the shared global mute behavior for the reels feed only.
      // Single-video detail playback uses local mute state so opening a video
      // does not leak a mute change back into the feed.
      if (mounted && widget.reels.length > 1) {
        media.isMuted.value = true;
      }
    });
    _muteListener = () {
      final vc = _vc;
      if (vc == null) return;
      try {
        vc.setVolume(media.isMuted.value ? 0.0 : media.volume.value);
      } catch (_) {
        // In rare cases the controller can be disposed while the listener fires.
      }
    };
    media.isMuted.addListener(_muteListener!);
    _reels = List<PostModel>.from(widget.reels);
    _index = widget.initialIndex.clamp(
      0,
      (widget.reels.length - 1).clamp(0, 999),
    );
    _page = PageController(initialPage: _index);
    _loadFirstPage();
    LocalStorage.getUserId().then((id) {
      if (mounted) setState(() => _meId = id);
    });
  }

  void _syncWakelock(bool shouldHold) {
    // Keep screen awake while a reel is actively playing.
    if (shouldHold == _wakelockHeld) return;
    _wakelockHeld = shouldHold;
    if (shouldHold) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    if (_muteListener != null) {
      media.isMuted.removeListener(_muteListener!);
    }
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _hideTimer = null;
    if (_activeFilePath != null) {
      VideoCacheService.instance.unregisterActivePath(_activeFilePath!);
      _activeFilePath = null;
    }
    final c = _vc;
    _vc = null;
    try {
      c?.pause();
    } catch (_) {}
    c?.dispose();
    _page.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _vc;
    if (c == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      try {
        c.pause();
      } catch (_) {}
    }
  }

  void _prepare(int idx) {
    final int token = ++_prepareToken;

    if (_activeFilePath != null) {
      VideoCacheService.instance.unregisterActivePath(_activeFilePath!);
      _activeFilePath = null;
    }

    final old = _vc;
    if (old != null) {
      old.removeListener(_playbackListener ?? () {});
      old.pause();
      old.dispose();
    }
    _vc = null;
    _init = null;
    _loopCount = 0;
    _syncWakelock(false);

    final post = _reels[idx];
    final m = post.media.isEmpty
        ? null
        : post.media.firstWhere(
            (x) => x.type.toUpperCase() == 'VIDEO',
            orElse: () => post.media.first,
          );
    final url = MediaUrl.normalize(m?.playbackUrl ?? m?.url ?? '');
    if (url.isEmpty) return;

    // Prefetch the NEXT item if available (only on Wi-Fi)
    if (idx + 1 < _reels.length) {
      final nextPost = _reels[idx + 1];
      final nextMedia = nextPost.media.isEmpty
          ? null
          : nextPost.media.firstWhere(
              (x) => x.type.toUpperCase() == 'VIDEO',
              orElse: () => nextPost.media.first,
            );
      final nextUrl = MediaUrl.normalize(
        nextMedia?.playbackUrl ?? nextMedia?.url ?? '',
      );
      if (nextUrl.isNotEmpty) {
        VideoCacheService.instance.prefetchVideo(nextUrl);
      }
    }

    // Playback listener template: applied once controller is constructed
    _playbackListener = () {
      final c = _vc;
      if (c == null) return;

      final v = c.value;
      _syncWakelock(v.isPlaying);

      // Update control visibility based on playback state
      if (v.isPlaying) {
        if (!_showControls) {
          setState(() => _showControls = true);
        }
        _resetHideTimer();
      } else {
        _cancelHideTimer();
        setState(() => _showControls = true);
      }

      final dur = v.duration;
      final pos = v.position;
      if (dur.inMilliseconds > 0 &&
          pos.inMilliseconds >= dur.inMilliseconds - 200) {
        if (_loopCount < 5) {
          _loopCount++;
          c.seekTo(Duration.zero).then((_) {
            if (!mounted || token != _prepareToken) return;
            c.play();
          });
        } else {
          c.pause();
        }
      }
    };

    _init = Future(() async {
      VideoPlayerController? controller;
      try {
        // Retrieve file from disk cache
        final file = await VideoCacheService.instance.getVideoFile(url);
        if (!mounted || token != _prepareToken) return;

        _activeFilePath = file.path;
        VideoCacheService.instance.registerActivePath(_activeFilePath!);

        controller = VideoPlayerController.file(file);
        _vc = controller;
        controller.addListener(_playbackListener!);

        await controller.initialize();
      } catch (e) {
        debugPrint(
          '[ReelsPlayer] Cache loading failed, unlinking key and falling back to network: $e',
        );
        if (_activeFilePath != null) {
          VideoCacheService.instance.unregisterActivePath(_activeFilePath!);
          _activeFilePath = null;
        }
        try {
          await VideoCacheService.instance.removeFile(url);
        } catch (_) {}

        if (!mounted || token != _prepareToken) return;

        // Fallback: network streaming directly
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
        _vc = controller;
        controller.addListener(_playbackListener!);

        await controller.initialize();
      }

      if (!mounted || token != _prepareToken) {
        controller.dispose();
        return;
      }

      controller.setLooping(false);
      controller.setVolume(media.isMuted.value ? 0.0 : media.volume.value);

      await controller.play();
      if (!mounted || token != _prepareToken) return;

      setState(() {});
    });

    if (mounted) setState(() {});
  }

  Future<void> _toggleLike(int postId, bool currentlyLiked) async {
    if (_likeBusyPostIds.contains(postId)) return;
    _likeBusyPostIds.add(postId);
    final i = _reels.indexWhere((p) => p.id == postId);
    if (i >= 0) {
      _reels[i] = _reels[i].copyWith(
        likeCount: (_reels[i].likeCount + (currentlyLiked ? -1 : 1)).clamp(
          0,
          1 << 30,
        ),
        isLikedByMe: !currentlyLiked,
      );
      if (mounted) setState(() {});
    }
    try {
      if (currentlyLiked) {
        final res = await _ds.unlikePost(postId);
        _applyCounts(postId, res);
      } else {
        final res = await _ds.likePost(postId);
        _applyCounts(postId, res);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Like failed: ${e.toString()}')));
    } finally {
      _likeBusyPostIds.remove(postId);
    }
  }

  void _applyCounts(int postId, Map<String, dynamic> data) {
    final i = _reels.indexWhere((p) => p.id == postId);
    if (i < 0) return;
    final p = _reels[i];
    _reels[i] = p.copyWith(
      likeCount: (data['likeCount'] as num?)?.toInt() ?? p.likeCount,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? p.commentCount,
      isLikedByMe: (data['isLikedByMe'] as bool?) ?? p.isLikedByMe,
    );
    if (mounted) setState(() {});
  }

  void _openComments(PostModel post) {
    final wasPlaying = _vc?.value.isPlaying ?? false;
    if (wasPlaying) {
      _vc?.pause();
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: CommentsSheet(
          postId: post.id,
          onCountChanged: (n) {
            final i = _reels.indexWhere((p) => p.id == post.id);
            if (i < 0) return;
            _reels[i] = _reels[i].copyWith(commentCount: n);
            if (mounted) setState(() {});
          },
        ),
      ),
    ).then((_) {
      if (wasPlaying && mounted) {
        _vc?.play();
      }
    });
  }

  void _showMoreMenu(PostModel post) {
    final wasPlaying = _vc?.value.isPlaying ?? false;
    if (wasPlaying) _vc?.pause();

    final isOwn = _meId != null && post.author.id == _meId;
    PostActionSheet.show(
      context,
      post: post,
      isOwn: isOwn,
      onViewFullPost: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailsScreen(post: post)),
      ),
      onPostChanged: (updated) {
        if (!mounted) return;
        final i = _reels.indexWhere((r) => r.id == updated.id);
        if (i >= 0) setState(() => _reels[i] = updated);
      },
    ).then((_) {
      if (wasPlaying && mounted) _vc?.play();
    });
  }

  /// Safe non-blocking view tracking fired once per reel on page change.
  void _trackView(int postId) {
    _ds.recordView(postId).catchError((_) => <String, dynamic>{});
  }

  Future<void> _loadFirstPage() async {
    if (!mounted) return;
    setState(() {
      _isLoadingFirstPage = true;
      _feedError = null;
      _currentPage = 1;
      _hasMore = true;
      _reels = const [];
    });
    await _fetchPage(1, replace: true);
  }

  Future<void> _fetchPage(int page, {required bool replace}) async {
    if (!mounted) return;
    if (replace) {
      _isLoadingFirstPage = true;
    } else {
      _isLoadingMore = true;
    }
    setState(() {});

    try {
      final result = await _ds.getVideosFeed(
        limit: _pageSize,
        page: page,
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        category: _categories[_selectedCategoryIndex],
        sort: _sort,
        duration: _duration,
        followingOnly: _useFollowingOnly,
      );
      if (!mounted) return;
      setState(() {
        if (replace) {
          _reels = result.items;
          _currentPage = 1;
          _index = 0;
          _feedError = null;
        } else {
          final existingIds = _reels.map((e) => e.id).toSet();
          _reels = [
            ..._reels,
            ...result.items.where((e) => !existingIds.contains(e.id)),
          ];
          _currentPage = page;
        }
        _hasMore = result.hasMore;
      });
      if (_reels.isNotEmpty) {
        if (_page.hasClients && replace) {
          _page.jumpToPage(0);
        }
        if (replace) _prepare(0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedError = e.toString().replaceFirst('Exception: ', '');
      });
      if (!replace) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load more videos: $_feedError'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _isLoadingFirstPage = false;
      _isLoadingMore = false;
    });
  }

  Future<void> _loadMoreIfNeeded(int index) async {
    if (_isLoadingFirstPage || _isLoadingMore || !_hasMore) return;
    if (index < _reels.length - 2) return;
    await _fetchPage(_currentPage + 1, replace: false);
  }

  void _applyCategory(int index) {
    final selected = _categories[index];
    setState(() {
      _selectedCategoryIndex = index;
      _useFollowingOnly = selected == 'Following';
    });
    _loadFirstPage();
  }

  void _setSearchQuery(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _searchQuery = value);
      _loadFirstPage();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() => _searchQuery = '');
    _loadFirstPage();
  }

  void _handleBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const FurtailHomeScreen(initialIndex: 4),
      ),
      (route) => false,
    );
  }

  void _openSearch() {
    final initial = _searchController.text;
    _searchController.text = initial;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101214),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
            ),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Search videos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        hintText: 'Search by caption or author',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white70,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setSheetState(() {});
                        _setSearchQuery(value);
                      },
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _feedError == null
                          ? 'Type to search videos.'
                          : _feedError!,
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setSheetState(() {});
                            _clearSearch();
                          },
                          child: const Text('Clear search'),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _openFilterSheet() {
    String sort = _sort;
    String? duration = _duration;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101214),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: sort,
                  dropdownColor: const Color(0xFF101214),
                  decoration: const InputDecoration(
                    labelText: 'Sort',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'latest', child: Text('Latest')),
                    DropdownMenuItem(
                      value: 'most_liked',
                      child: Text('Most liked'),
                    ),
                    DropdownMenuItem(
                      value: 'most_commented',
                      child: Text('Most commented'),
                    ),
                  ],
                  onChanged: (v) => setState(() => sort = v ?? sort),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: duration,
                  dropdownColor: const Color(0xFF101214),
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Any length')),
                    DropdownMenuItem(value: 'short', child: Text('Short')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'long', child: Text('Long')),
                  ],
                  onChanged: (v) => setState(() => duration = v),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_categories.length, (i) {
                    final category = _categories[i];
                    final isSelected = i == _selectedCategoryIndex;
                    return FilterChip(
                      selected: isSelected,
                      label: Text(category),
                      onSelected: (_) {
                        Navigator.pop(sheetCtx);
                        _applyCategory(i);
                      },
                      selectedColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.18),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          sort = 'latest';
                          duration = null;
                          _selectedCategoryIndex = 0;
                          _useFollowingOnly = false;
                        });
                        _sort = 'latest';
                        _duration = null;
                        _searchQuery = '';
                        _searchController.clear();
                        Navigator.pop(sheetCtx);
                        _loadFirstPage();
                      },
                      child: const Text('Reset'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        _sort = sort;
                        _duration = duration;
                        Navigator.pop(sheetCtx);
                        _loadFirstPage();
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildTopControls(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: topInset + 8,
              left: 12,
              right: 12,
              bottom: 10,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC000000),
                  Color(0x66000000),
                  Color(0x00000000),
                ],
              ),
            ),
            child: Row(
              children: [
                _buildCircleActionButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: _handleBack,
                ),
                const Spacer(),
                _buildCircleActionButton(
                  icon: Icons.search_rounded,
                  tooltip: 'Search',
                  onTap: _openSearch,
                ),
                const SizedBox(width: 10),
                _buildCircleActionButton(
                  icon: Icons.filter_alt_rounded,
                  tooltip: 'Filter',
                  onTap: _openFilterSheet,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final selected = index == _selectedCategoryIndex;
                return ChoiceChip(
                  label: Text(_categories[index]),
                  selected: selected,
                  showCheckmark: selected,
                  onSelected: (_) => _applyCategory(index),
                  selectedColor: Colors.white,
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                  labelStyle: TextStyle(
                    color: selected ? cs.primary : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.18),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: _categories.length,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // â”€â”€ Single-video detail helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _detailTogglePlayPause() {
    final vc = _vc;
    if (vc == null) return;
    final wasPlaying = vc.value.isPlaying;
    if (wasPlaying) {
      vc.pause();
    } else {
      vc.play();
    }
    _showDetailControls();
    if (wasPlaying) {
      _cancelHideTimer();
    } else {
      _resetHideTimer();
    }
  }

  void _showDetailControls() {
    if (!mounted) return;
    setState(() => _showControls = true);
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    final vc = _vc;
    if (vc == null || !vc.value.isPlaying) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _handleDetailInteraction() {
    _showDetailControls();
    _resetHideTimer();
  }

  void _seekDetailBy(Duration delta) {
    final vc = _vc;
    if (vc == null) return;
    final duration = vc.value.duration;
    final target = vc.value.position + delta;
    final bounded = target < Duration.zero
        ? Duration.zero
        : (target > duration ? duration : target);
    vc.seekTo(bounded);
    _handleDetailInteraction();
  }

  void _toggleDetailMute() {
    final vc = _vc;
    if (vc == null) return;
    if (widget.reels.length == 1) {
      setState(() => _detailMuted = !_detailMuted);
      vc.setVolume(_detailMuted ? 0.0 : media.volume.value);
    } else {
      media.toggleMute();
      vc.setVolume(media.isMuted.value ? 0.0 : media.volume.value);
    }
    _handleDetailInteraction();
  }

  double _detailAspectRatio(PostModel post) {
    final vc = _vc;
    if (vc != null && vc.value.isInitialized && vc.value.aspectRatio > 0) {
      return vc.value.aspectRatio;
    }

    final mediaItem = post.media.firstWhere(
      (m) => m.type.toUpperCase() == 'VIDEO',
      orElse: () => post.media.first,
    );
    final width = mediaItem.width;
    final height = mediaItem.height;
    if (width != null && height != null && height > 0) {
      final ratio = width / height;
      if (ratio.isFinite && ratio > 0) {
        return ratio;
      }
    }
    return 16 / 9;
  }

  @override
  Widget build(BuildContext context) {
    final reels = _reels;
    if (_isLoadingFirstPage && reels.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Text(
              _feedError ?? 'No reels',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Single video: show Facebook-style detail layout
    if (reels.length == 1) {
      return _buildVideoDetail(context, reels[0]);
    }

    // Multiple reels: keep TikTok-style swiper
    return _buildReelSwiper(context, reels);
  }

  // â”€â”€ Single-video detail â€” Facebook-style â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //
  // Layout (top to bottom):
  //   AppBar: back + "Video" title + more menu
  //   Video player area (capped at 55% screen height)
  //     â€” controls INSIDE the video frame only
  //   Scrollable content below:
  //     Author row, caption, stats, Like/Comment/Share, comments
  //   Fullscreen via dedicated page (_FullscreenVideoPage)
  Widget _buildVideoDetail(BuildContext context, PostModel post) {
    final vc = _vc;
    final init = _init;
    final theme = Theme.of(context);
    final likeLabel =
        Localizations.localeOf(context).languageCode == 'bn' ? 'লাইক' : 'Like';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.40),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Video',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => _showMoreMenu(post),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // â”€â”€ 1. Video player area â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Flexible(
              flex: 5,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availW = constraints.maxWidth;
                  final availH = constraints.maxHeight;
                  final ar = _detailAspectRatio(post);
                  double videoW = availW;
                  double videoH = availW / ar;
                  if (ar < 1) {
                    final minHeight = availH * 0.48;
                    final maxHeight = availH * 0.94;
                    videoH = videoH.clamp(minHeight, maxHeight).toDouble();
                    videoW = videoH * ar;
                  } else if (videoH > availH) {
                    videoH = availH;
                    videoW = availH * ar;
                  }

                  return Container(
                    color: Colors.black,
                    width: availW,
                    height: availH,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Video surface
                        if (vc == null || init == null)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white38,
                            ),
                          )
                        else
                          FutureBuilder<void>(
                            future: init,
                            builder: (_, snap) {
                              if (snap.connectionState !=
                                  ConnectionState.done) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white38,
                                  ),
                                );
                              }
                              if (snap.hasError) {
                                return const Center(
                                  child: Icon(
                                    Icons.error_outline,
                                    color: Colors.white38,
                                    size: 48,
                                  ),
                                );
                              }
                              return Center(
                                child: SizedBox(
                                  width: videoW,
                                  height: videoH,
                                  child: VideoPlayer(vc),
                                ),
                              );
                            },
                          ),

                        // Tap to toggle controls
                        if (vc != null)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                _showControls = !_showControls;
                              });
                              if (_showControls && vc.value.isPlaying) {
                                _resetHideTimer();
                              } else {
                                _cancelHideTimer();
                              }
                            },
                            child: const SizedBox.expand(),
                          ),

                        // Center seek and play controls
                        if (vc != null && _showControls)
                          ValueListenableBuilder<VideoPlayerValue>(
                            valueListenable: vc,
                            builder: (_, v, _) {
                              return Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _OverlayControlButton(
                                      icon: Icons.replay_10,
                                      size: 58,
                                      iconSize: 30,
                                      onTap: () => _seekDetailBy(
                                        const Duration(seconds: -10),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _OverlayControlButton(
                                      icon: v.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      size: 76,
                                      iconSize: 42,
                                      backgroundColor: Colors.white,
                                      iconColor: Colors.black87,
                                      onTap: _detailTogglePlayPause,
                                    ),
                                    const SizedBox(width: 12),
                                    _OverlayControlButton(
                                      icon: Icons.forward_10,
                                      size: 58,
                                      iconSize: 30,
                                      onTap: () => _seekDetailBy(
                                        const Duration(seconds: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                        // Buffering spinner
                        if (vc != null)
                          ValueListenableBuilder<VideoPlayerValue>(
                            valueListenable: vc,
                            builder: (_, v, _) {
                              if (!v.isBuffering) {
                                return const SizedBox.shrink();
                              }
                              return const Center(
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    color: Colors.white54,
                                  ),
                                ),
                              );
                            },
                          ),

                        // Visible fullscreen affordance inside the safe area.
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 12,
                          left: 12,
                          child: _OverlayControlButton(
                            icon: Icons.fullscreen_rounded,
                            size: 42,
                            iconSize: 20,
                            onTap: () => _openFullscreen(post),
                          ),
                        ),

                        // Mute control inside the video frame
                        if (vc != null && _showControls)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: widget.reels.length == 1
                                ? _OverlayControlButton(
                                    icon: _detailMuted
                                        ? Icons.volume_off
                                        : Icons.volume_up,
                                    size: 50,
                                    iconSize: 22,
                                    onTap: _toggleDetailMute,
                                  )
                                : ValueListenableBuilder<bool>(
                                    valueListenable: media.isMuted,
                                    builder: (_, isMuted, _) {
                                      return _OverlayControlButton(
                                        icon: isMuted
                                            ? Icons.volume_off
                                            : Icons.volume_up,
                                        size: 50,
                                        iconSize: 22,
                                        onTap: _toggleDetailMute,
                                      );
                                    },
                                  ),
                          ),

                        // Progress/seek bar at bottom of video
                        if (vc != null && _showControls)
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: 8,
                            child: _InlineSeekBar(
                              controller: vc,
                              onFullscreen: () => _openFullscreen(post),
                              onInteraction: _handleDetailInteraction,
                              onScrubStart: _showDetailControls,
                              onScrubEnd: _handleDetailInteraction,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // â”€â”€ 2. Divider â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Container(height: 1, color: Colors.grey.shade800),

            // â”€â”€ 3. Content below video â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Flexible(
              flex: 4,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author row
                    InkWell(
                      onTap: () {
                        final uid = post.author.id;
                        if (uid <= 0) return;
                        final wasPlaying = vc?.value.isPlaying ?? false;
                        if (wasPlaying) vc?.pause();
                        ProfileNavigation.openUserProfile(context, uid).then((
                          _,
                        ) {
                          if (wasPlaying && mounted) vc?.play();
                        });
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white12,
                            backgroundImage:
                                (post.author.avatarUrl ?? '').isNotEmpty
                                ? NetworkImage(post.author.avatarUrl!)
                                : null,
                            child: (post.author.avatarUrl ?? '').isEmpty
                                ? const Icon(
                                    Icons.person,
                                    color: Colors.white60,
                                    size: 18,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.author.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _timeAgo(post.createdAt),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Caption
                    if ((post.caption ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          post.caption!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),

                    // Stats row
                    const SizedBox(height: 8),

                    Divider(color: Colors.grey.shade800, height: 1),
                    const SizedBox(height: 4),

                    // Action row: Like, Comment, Share
                    Row(
                      children: [
                        _DetailActionButton(
                          icon: post.isLikedByMe
                              ? Icons.pets
                              : Icons.pets_outlined,
                          label: '$likeLabel (${post.likeCount})',
                          color: post.isLikedByMe
                              ? theme.colorScheme.primary
                              : Colors.white70,
                          onTap: () => _toggleLike(post.id, post.isLikedByMe),
                        ),
                        _DetailActionButton(
                          icon: Icons.comment_outlined,
                          label: 'Comment (${post.commentCount})',
                          color: Colors.white70,
                          onTap: () => _openComments(post),
                        ),
                        _DetailActionButton(
                          icon: Icons.share_outlined,
                          label: 'Share (${post.shareCount})',
                          color: Colors.white70,
                          onTap: () {
                            final fid = post.fundraisingCampaignId;
                            if (fid != null) {
                              ShareService.share(
                                context,
                                type: 'fundraising',
                                id: fid,
                              );
                            } else {
                              ShareService.share(
                                context,
                                type: 'post',
                                id: post.id,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    Divider(color: Colors.grey.shade800, height: 1),
                    const SizedBox(height: 8),

                    // Comments
                    Text(
                      'Comments',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => _openComments(post),
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white54,
                            size: 16,
                          ),
                          label: Text(
                            'View all ${post.commentCount} comments',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens a true fullscreen landscape player.
  /// Pauses the inline controller first; the fullscreen page creates its own.
  void _openFullscreen(PostModel post) {
    final wasPlaying = _vc?.value.isPlaying ?? false;
    final startMuted =
        widget.reels.length == 1 ? _detailMuted : media.isMuted.value;
    final startAt = _vc?.value.position ?? Duration.zero;
    final mediaItem = post.media.isEmpty
        ? null
        : post.media.firstWhere(
            (x) => x.type.toUpperCase() == 'VIDEO',
            orElse: () => post.media.first,
          );
    final url = MediaUrl.normalize(mediaItem?.url ?? '');
    if (url.isEmpty) return;
    _vc?.pause();
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullscreenVideoPlayerScreen(
          url: url,
          startAt: startAt,
          startMuted: startMuted,
          autoplay: wasPlaying,
        ),
      ),
    ).then((_) {
      // Resume portrait playback if the video was playing before fullscreen.
      if (wasPlaying && mounted) _vc?.play();
    });
  }

  // â”€â”€ TikTok-style swiper for multiple reels (unchanged) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildReelSwiper(BuildContext context, List<PostModel> reels) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            onPageChanged: (i) {
              _index = i;
              _prepare(i);
              _trackView(reels[i].id);
              _loadMoreIfNeeded(i);
            },
            itemBuilder: (_, i) {
              final post = reels[i];
              final isCurrent = i == _index;
              final vc = isCurrent ? _vc : null;
              final init = isCurrent ? _init : null;

              return _ReelPage(
                post: post,
                controller: vc,
                init: init,
                onLike: () => _toggleLike(post.id, post.isLikedByMe),
                onComment: () => _openComments(post),
                onToggleMute: media.toggleMute,
                onShare: () {
                  final fundraisingId = post.fundraisingCampaignId;
                  if (fundraisingId != null) {
                    ShareService.share(
                      context,
                      type: 'fundraising',
                      id: fundraisingId,
                    );
                  } else {
                    ShareService.share(context, type: 'post', id: post.id);
                  }
                },
                onReport: () =>
                    ReportBottomSheet.showPost(context, postId: post.id),
                onFullscreen: () => _openFullscreen(post),
                onNavigateToProfile: () {
                  final uid = post.author.id;
                  if (uid <= 0) return;
                  final wasPlaying = _vc?.value.isPlaying ?? false;
                  if (wasPlaying) _vc?.pause();
                  ProfileNavigation.openUserProfile(context, uid).then((_) {
                    if (wasPlaying && mounted) _vc?.play();
                  });
                },
                onOpenMoreMenu: () => _showMoreMenu(post),
              );
            },
          ),
          if (_isLoadingMore)
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          _buildTopControls(context),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Inline seek bar â€” used inside the bounded video Stack in single-video detail.
// Does NOT use SafeArea (intentional: the container is bounded, not full-screen).
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _InlineSeekBar extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onFullscreen;
  final VoidCallback onInteraction;
  final VoidCallback onScrubStart;
  final VoidCallback onScrubEnd;

  const _InlineSeekBar({
    required this.controller,
    this.onFullscreen = _noop,
    this.onInteraction = _noop,
    this.onScrubStart = _noop,
    this.onScrubEnd = _noop,
  });

  static void _noop() {}

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (_, v, _) {
          final durMs = v.duration.inMilliseconds;
          final posMs = v.position.inMilliseconds;
          final sliderVal = durMs <= 0
              ? 0.0
              : (posMs / durMs).clamp(0.0, 1.0).toDouble();
          return Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      _fmt(v.position),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _fmt(v.duration),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () {
                        onFullscreen();
                        onInteraction();
                      },
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6.0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14.0,
                    ),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    value: sliderVal,
                    min: 0.0,
                    max: 1.0,
                    onChangeStart: durMs > 0 ? (_) => onScrubStart() : null,
                    onChanged: durMs > 0
                        ? (val) {
                            onInteraction();
                            controller.seekTo(
                              Duration(milliseconds: (val * durMs).round()),
                            );
                          }
                        : null,
                    onChangeEnd: durMs > 0 ? (_) => onScrubEnd() : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OverlayControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color iconColor;

  const _OverlayControlButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onTap,
    this.backgroundColor,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.black.withValues(alpha: 0.42),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: iconSize),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Fullscreen landscape video player page.
//
// â€¢ Forces landscape on push, restores portrait + system UI on dispose.
// â€¢ Creates its own VideoPlayerController (network URL) so the inline
//   portrait controller is completely decoupled.
// â€¢ Shows a close button in the top-left corner and a seek bar at the bottom.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FullscreenVideoPage extends StatefulWidget {
  final PostModel post;
  const _FullscreenVideoPage({required this.post});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    // Force landscape for fullscreen playback.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // Resolve video URL the same way _prepare() does.
    final m = widget.post.media.isEmpty
        ? null
        : widget.post.media.firstWhere(
            (x) => x.type.toUpperCase() == 'VIDEO',
            orElse: () => widget.post.media.first,
          );
    final url = MediaUrl.normalize(m?.url ?? '');

    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller.play();
        _scheduleHide();
      });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    // Restore portrait orientation and system UI when exiting fullscreen.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          children: [
            // â”€â”€ Centred video with correct aspect ratio â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Center(
              child: _initialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(color: Colors.white54),
            ),

            // â”€â”€ Controls overlay (auto-hides) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (_showControls || !_initialized) ...[
              // Close button â€” top-left with safe area
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.50),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),

              // Play/pause centre button
              if (_initialized)
                Center(
                  child: GestureDetector(
                    onTap: () {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                        _scheduleHide();
                      }
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),

              // Seek bar â€” pinned to bottom with bottom safe-area inset
              if (_initialized)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).padding.bottom,
                  child: _InlineSeekBar(controller: _controller),
                ),
            ],

            // Buffering indicator
            if (_initialized && _controller.value.isBuffering)
              const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// TikTok-style reel page (full-screen, swipe-up feed)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ReelPage extends StatefulWidget {
  final PostModel post;
  final VideoPlayerController? controller;
  final Future<void>? init;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final VoidCallback onToggleMute;
  final VoidCallback onFullscreen;
  final VoidCallback onNavigateToProfile;
  final VoidCallback onOpenMoreMenu;

  const _ReelPage({
    required this.post,
    required this.controller,
    required this.init,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onReport,
    required this.onToggleMute,
    required this.onFullscreen,
    required this.onNavigateToProfile,
    required this.onOpenMoreMenu,
  });

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  bool _captionVisible = true;
  bool _uiVisible = true;
  bool _captionExpanded = false;
  Timer? _uiHideTimer;
  double _lastTapDx = 0;
  Timer? _autoHideTimer;
  bool _showToggleIcon = false;
  bool _toggleWasPlay = false;
  Timer? _toggleIconTimer;

  @override
  void initState() {
    super.initState();
    // First reel: schedule auto-hide once initialized.
    widget.init?.then((_) {
      if (!mounted) return;
      _scheduleAutoHide();
    });
  }

  @override
  void didUpdateWidget(covariant _ReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _autoHideTimer?.cancel();
      _captionVisible = true;
      // When the new reel is ready, hide text after a few seconds.
      widget.init?.then((_) {
        if (!mounted) return;
        _scheduleAutoHide();
      });
    }
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _uiHideTimer?.cancel();
    _toggleIconTimer?.cancel();
    super.dispose();
  }

  void _scheduleUiAutoHide() {
    _uiHideTimer?.cancel();
    _uiHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _uiVisible = false);
    });
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    setState(() {
      _captionVisible = true;
      _uiVisible = true;
    });
    _scheduleUiAutoHide();
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      // Only hide if still playing and caption not expanded.
      if (_captionExpanded) return;
      final c = widget.controller;
      if (c != null && c.value.isPlaying) {
        setState(() => _captionVisible = false);
      }
    });
  }

  Future<void> _showVolumePopup(BuildContext context) async {
    final media = MediaPlaybackController.instance;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: ValueListenableBuilder<double>(
              valueListenable: media.volume,
              builder: (_, vol, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sound',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: vol.clamp(0.0, 1.0).toDouble(),
                      min: 0.0,
                      max: 1.0,
                      onChanged: (v) {
                        media.setVolume(v);
                        // If user drags volume up, auto unmute.
                        if (media.isMuted.value && v > 0) {
                          media.isMuted.value = false;
                        }
                        final c = widget.controller;
                        if (c != null) {
                          c.setVolume(
                            media.isMuted.value ? 0.0 : media.volume.value,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      media.isMuted.value ? 'Muted' : 'On',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final controller = widget.controller;
    final init = widget.init;
    final likeLabel =
        Localizations.localeOf(context).languageCode == 'bn' ? 'লাইক' : 'Like';

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _lastTapDx = d.localPosition.dx,
          onTap: () {
            final c = widget.controller;
            if (c != null) {
              final wasPlaying = c.value.isPlaying;
              if (wasPlaying) {
                c.pause();
                _scheduleUiAutoHide();
              } else {
                c.play();
                _scheduleUiAutoHide();
              }
              // Show flash toggle icon
              _toggleIconTimer?.cancel();
              setState(() {
                _showToggleIcon = true;
                _toggleWasPlay = !wasPlaying;
                _uiVisible = true;
                _captionVisible = true;
              });
              _toggleIconTimer = Timer(const Duration(milliseconds: 700), () {
                if (mounted) setState(() => _showToggleIcon = false);
              });
            } else {
              setState(() {
                final next = !_uiVisible;
                _uiVisible = next;
                _captionVisible = next;
              });
              if (_uiVisible) _scheduleUiAutoHide();
            }
          },
          onDoubleTap: widget.onLike, // double tap = like (Premium UX)
          onLongPressStart: (_) {
            // Long press on the RIGHT side = 1.5x speed.
            if (_lastTapDx >= w * 0.65) {
              controller?.setPlaybackSpeed(1.5);
            }
          },
          onLongPressEnd: (_) {
            controller?.setPlaybackSpeed(1.0);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (controller == null || init == null)
                const Center(child: CircularProgressIndicator())
              else
                FutureBuilder<void>(
                  future: init,
                  builder: (_, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final ratio = controller.value.aspectRatio > 0
                        ? controller.value.aspectRatio
                        : 9 / 16;
                    final isPortrait = ratio < 1.0;

                    return Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: AspectRatio(
                        aspectRatio: isPortrait ? ratio : ratio,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: controller.value.size.width,
                            height: controller.value.size.height,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Gradient for legibility
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
              ),

              // Right side actions (always visible)
              Positioned(
                right: 12,
                bottom: 110,
                child: Column(
                  children: [
                    _OverlayControlButton(
                      icon: Icons.fullscreen_rounded,
                      size: 42,
                      iconSize: 20,
                      onTap: widget.onFullscreen,
                    ),
                    const SizedBox(height: 16),
                    ReelActionButton(
                      icon: post.isLikedByMe
                          ? Icons.favorite
                          : Icons.favorite_border,
                      label: '$likeLabel (${post.likeCount})',
                      onTap: widget.onLike,
                    ),
                    const SizedBox(height: 16),
                    ReelActionButton(
                      icon: Icons.comment_outlined,
                      label: 'Comment (${post.commentCount})',
                      onTap: widget.onComment,
                    ),
                    const SizedBox(height: 16),
                    ReelActionButton(
                      icon: Icons.share_rounded,
                      label: 'Share (${post.shareCount})',
                      onTap: widget.onShare,
                    ),
                    const SizedBox(height: 16),
                    ReelActionButton(
                      icon: Icons.flag_outlined,
                      label: 'Report',
                      onTap: widget.onReport,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        widget.onToggleMute();
                        final c = controller;
                        if (c != null) {
                          final media = MediaPlaybackController.instance;
                          c.setVolume(
                            media.isMuted.value ? 0.0 : media.volume.value,
                          );
                        }
                      },
                      onLongPress: () => _showVolumePopup(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: ValueListenableBuilder<bool>(
                          valueListenable:
                              MediaPlaybackController.instance.isMuted,
                          builder: (_, isMuted, _) {
                            return Column(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isMuted
                                        ? Icons.volume_off_rounded
                                        : Icons.volume_up_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isMuted ? 'Muted' : 'Sound',
                                  style: Theme.of(context).textTheme.bodySmall!
                                      .copyWith(
                                        color: Colors.white,
                                        shadows: const [
                                          Shadow(
                                            blurRadius: 4,
                                            color: Colors.black54,
                                          ),
                                        ],
                                      ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Flash icon on tap â€” kept in tree so AnimatedOpacity can fade out.
              IgnorePointer(
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _showToggleIcon ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.50),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _toggleWasPlay
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: Colors.white,
                        size: 52,
                      ),
                    ),
                  ),
                ),
              ),

              // Persistent play icon when paused and UI visible
              if (controller != null && _uiVisible && !_showToggleIcon)
                IgnorePointer(
                  child: Center(
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: controller,
                      builder: (_, v, _) {
                        if (v.isPlaying) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 46,
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Caption/Text area (auto hides after 3-4 seconds)
              if (_captionVisible)
                Positioned(
                  left: 12,
                  right: 80,
                  bottom: 72,
                  child: GestureDetector(
                    onTap: () {},
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author row
                        InkWell(
                          onTap: widget.onNavigateToProfile,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.white10,
                                backgroundImage:
                                    (post.author.avatarUrl ?? '').isNotEmpty
                                    ? NetworkImage(post.author.avatarUrl!)
                                    : null,
                                child: (post.author.avatarUrl ?? '').isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.white70,
                                        size: 16,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  post.author.name,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Caption text with expand/collapse
                        if ((post.caption ?? '').isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.caption!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.3,
                                ),
                                maxLines: _captionExpanded ? null : 2,
                                overflow: _captionExpanded
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                              ),
                              if (post.caption!.length > 100)
                                InkWell(
                                  onTap: () => setState(
                                    () => _captionExpanded = !_captionExpanded,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      _captionExpanded ? 'less' : 'more',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

              // Bottom seek bar (for swipe feed â€” uses SafeArea for system nav)
              if (controller != null)
                Positioned(
                  left: 0,
                  right: 76,
                  bottom: 0,
                  child: ReelSeekBar(controller: controller),
                ),

              // Subtle buffering hint
              if (controller != null && controller.value.isBuffering)
                const Center(
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Right-rail action button for the single-video detail view.
// Supports a custom icon color (e.g. primary colour when liked).
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Horizontal action button used below the video (Like/Comment/Share).
class _DetailActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DetailActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


