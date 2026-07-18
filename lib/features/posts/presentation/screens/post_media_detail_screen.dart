import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:furtail_app/core/media/feed_video_player.dart';
import 'package:furtail_app/core/media/furtail_cache_manager.dart';
import 'package:furtail_app/core/permissions/permission_service.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/presentation/widgets/comments_sheet.dart';
import 'package:furtail_app/features/posts/presentation/widgets/media_engagement.dart';

/// @deprecated Use [MediaViewerScreen] instead via [AppRoutes.mediaViewer].
/// The router now redirects [AppRoutes.postMediaDetail] to [MediaViewerScreen]
/// when a full [PostModel] is available. This screen is kept as a fallback
/// for legacy callers that pass individual fields.
class PostMediaDetailScreen extends StatefulWidget {
  final int postId;
  final List<PostMediaModel> media;
  final int initialIndex;
  final PostAuthorModel author;
  final String caption;
  final PostModel? post;

  const PostMediaDetailScreen({
    super.key,
    required this.postId,
    required this.media,
    required this.initialIndex,
    required this.author,
    required this.caption,
    this.post,
  });

  @override
  State<PostMediaDetailScreen> createState() => _PostMediaDetailScreenState();
}

class _PostMediaDetailScreenState extends State<PostMediaDetailScreen> {
  final _ds = PostsRemoteDs();
  late List<MediaEngagementSummary> _engagements;
  late final ScrollController _scrollController;
  late final List<GlobalKey> _itemKeys;
  int _currentIndex = 0;
  bool _scrolledToInitial = false;
  final Set<int> _likeBusyIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.media.length - 1);
    _scrollController = ScrollController();
    _itemKeys = List.generate(widget.media.length, (_) => GlobalKey());

    // Initialize per-media engagement models.
    // Falls back to post-level counts if per-media is not yet supported.
    _engagements = widget.media.map((m) {
      return MediaEngagementSummary(
        mediaId: m.id,
        likeCount: widget.post?.likeCount ?? 0,
        commentCount: widget.post?.commentCount ?? 0,
        shareCount: 0,
        isLiked: widget.post?.isLikedByMe ?? false,
      );
    }).toList();

    // Scroll to initial index once the widgets are laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrolledToInitial && mounted) {
        _scrollToIndex(_currentIndex);
        _scrolledToInitial = true;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (index >= 0 && index < _itemKeys.length) {
      final context = _itemKeys[index].currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.0,
          duration: Duration.zero,
        );
      }
    }
  }

  Future<void> _toggleLike(int index) async {
    if (_likeBusyIndexes.contains(index)) return;
    _likeBusyIndexes.add(index);
    final summary = _engagements[index];
    final currentlyLiked = summary.isLiked;

    // Optimistic UI update
    setState(() {
      _engagements[index] = summary.copyWith(
        isLiked: !currentlyLiked,
        likeCount: (summary.likeCount + (currentlyLiked ? -1 : 1)).clamp(
          0,
          999999,
        ),
      );
    });

    try {
      // TODO: Connect media-level toggle-like API endpoint here once supported:
      // await _ds.likeMedia(summary.mediaId);

      // Fallback: Map to post-level endpoints
      final res = currentlyLiked
          ? await _ds.unlikePost(widget.postId)
          : await _ds.likePost(widget.postId);

      final likeCount = (res['likeCount'] as num?)?.toInt();
      final isLikedByMe = (res['isLikedByMe'] as bool?);

      if (mounted) {
        setState(() {
          _engagements[index] = _engagements[index].copyWith(
            likeCount: likeCount ?? _engagements[index].likeCount,
            isLiked: isLikedByMe ?? _engagements[index].isLiked,
          );
        });
      }
    } catch (e) {
      // Rollback on failure
      if (mounted) {
        setState(() {
          _engagements[index] = summary;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Like action failed: $e')));
      }
    } finally {
      _likeBusyIndexes.remove(index);
    }
  }

  void _openComments(int index) {
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
          postId: widget.postId,
          // TODO: Connect media-level comment endpoint here once supported
          onCountChanged: (n) {
            if (mounted) {
              setState(() {
                _engagements[index] = _engagements[index].copyWith(
                  commentCount: n,
                );
              });
            }
          },
        ),
      ),
    );
  }

  void _sharePost(int index) {
    // TODO: Connect media-level share endpoints here once supported
    final mediaItem = widget.media[index];
    _shareMediaUrl(mediaItem);
  }

  // --- Image Actions: Download & Share ---

  Future<void> _shareMediaUrl(PostMediaModel mediaItem) async {
    if (mediaItem.url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot share: URL is empty or processing.'),
        ),
      );
      return;
    }
    await Share.share(mediaItem.url);
  }

  Future<void> _shareMediaFile(PostMediaModel mediaItem) async {
    if (mediaItem.url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot share: URL is empty or processing.'),
        ),
      );
      return;
    }
    try {
      final response = await http.get(Uri.parse(mediaItem.url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final extension = mediaItem.type.toUpperCase() == 'VIDEO'
            ? 'mp4'
            : 'jpg';
        final file = File(
          '${tempDir.path}/shared_media_${mediaItem.id}.$extension',
        );
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Shared from Furtail');
      } else {
        throw Exception('Failed to download media file from server');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share file: $e')));
      }
    }
  }

  Future<void> _downloadMedia(PostMediaModel mediaItem) async {
    if (mediaItem.url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot download: URL is empty or processing.'),
        ),
      );
      return;
    }

    if (mediaItem.type.toUpperCase() == 'VIDEO') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Video downloading is not supported yet. Please share the link instead.',
          ),
        ),
      );
      return;
    }

    try {
      final hasPhotos = await PermissionService().ensure(AppPermission.photos);
      if (!hasPhotos) {
        final hasStorage = await PermissionService().ensure(
          AppPermission.storage,
        );
        if (!hasStorage) {
          throw Exception('Storage/Photo permission denied');
        }
      }

      final response = await http.get(Uri.parse(mediaItem.url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image from server');
      }
      final bytes = response.bodyBytes;

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      dir ??= await getTemporaryDirectory();

      final fileName =
          'furtail_image_${mediaItem.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded successfully to: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  void _showMoreMenu(PostMediaModel item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Share Link'),
              onTap: () {
                Navigator.pop(ctx);
                _shareMediaUrl(item);
              },
            ),
            if (item.type.toUpperCase() == 'IMAGE') ...[
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share Image File'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareMediaFile(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download Image'),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadMedia(item);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.download_for_offline_outlined),
                title: const Text('Download Video'),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadMedia(item);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1}/${widget.media.length}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => _showMoreMenu(widget.media[_currentIndex]),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Post Author & Caption Header at the top of the detail list
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFEFEFEF),
                                backgroundImage:
                                    (widget.author.avatarUrl ?? '').isEmpty
                                    ? null
                                    : NetworkImage(widget.author.avatarUrl!),
                                child: (widget.author.avatarUrl ?? '').isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.black45,
                                        size: 20,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.author.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.caption.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              widget.caption,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    // Render vertical media stack
                    ...List.generate(widget.media.length, (index) {
                      final item = widget.media[index];
                      return VisibilityDetector(
                        key: Key('detail-visibility-$index'),
                        onVisibilityChanged: (info) {
                          if (info.visibleFraction > 0.5 && mounted) {
                            setState(() {
                              _currentIndex = index;
                            });
                          }
                        },
                        child: Container(
                          key: _itemKeys[index],
                          color: Colors.black,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              // Media element
                              _buildMediaContent(item),
                              // Actions bar
                              MediaEngagementActions(
                                summary: _engagements[index],
                                onLikeToggle: () => _toggleLike(index),
                                onCommentPressed: () => _openComments(index),
                                onSharePressed: () => _sharePost(index),
                              ),
                              const Divider(
                                color: Colors.white10,
                                height: 24,
                                thickness: 4,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(PostMediaModel item) {
    if (item.type.toUpperCase() == 'VIDEO') {
      double ratio = 16 / 9;
      if (item.width != null && item.height != null && item.height! > 0) {
        ratio = item.width! / item.height!;
      }
      return Center(
        child: FeedVideoPlayer(
          url: item.playbackUrl,
          visibilityKey: 'detail-video-${item.id}',
          startMuted: false, // detail screen plays sound
          syncMuteWithGlobal: false,
          enableAutoplay: true,
          aspectRatio: ratio,
          fit: BoxFit.contain, // contain without cropping
        ),
      );
    }

    // IMAGE
    return Center(
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 3.5,
        child: CachedNetworkImage(
          imageUrl: item.url,
          cacheManager: FurtailImageCacheManager(),
          fit: BoxFit.contain,
          placeholder: (_, _) => const SizedBox(
            height: 250,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white70,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
          errorWidget: (_, _, _) => const SizedBox(
            height: 200,
            child: Center(
              child: Icon(Icons.broken_image, color: Colors.white30, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
