import 'package:flutter/material.dart';

import 'package:furtail_app/core/constants/app_colors.dart';
import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/core/widgets/social_action_row.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/presentation/widgets/comments_sheet.dart';

/// Feed-style reactions (Like/Comment/Share) to match Home feed UI.
class FundraisingReactionsSection extends StatefulWidget {
  final int postId;
  final int fundraisingId;
  final bool initialLikedByMe;
  final int initialLikeCount;
  final int commentCount;

  const FundraisingReactionsSection({
    super.key,
    required this.postId,
    required this.fundraisingId,
    required this.initialLikedByMe,
    required this.initialLikeCount,
    required this.commentCount,
  });

  @override
  State<FundraisingReactionsSection> createState() =>
      _FundraisingReactionsSectionState();
}

class _FundraisingReactionsSectionState
    extends State<FundraisingReactionsSection> {
  final _postsDs = PostsRemoteDs();
  late bool _liked;
  late int _likes;
  bool _likeBusy = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.initialLikedByMe;
    _likes = widget.initialLikeCount;
  }

  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    setState(() => _likeBusy = true);
    final wasLiked = _liked;
    setState(() {
      _liked = !wasLiked;
      _likes += wasLiked ? -1 : 1;
      if (_likes < 0) _likes = 0;
    });

    try {
      if (wasLiked) {
        await _postsDs.unlikePost(widget.postId);
      } else {
        await _postsDs.likePost(widget.postId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = wasLiked;
        _likes += wasLiked ? 1 : -1;
        if (_likes < 0) _likes = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Like failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommentsSheet(postId: widget.postId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SocialActionRow(
      likeCount: _likes,
      commentCount: widget.commentCount,
      shareCount: 0,
      isLiked: _liked,
      onLike: _toggleLike,
      onComment: _openComments,
      onShare: () {
        ShareService.share(
          context,
          type: 'fundraising',
          id: widget.fundraisingId,
        );
      },
      foregroundColor: Colors.black87,
      selectedColor: AppColors.donateBlue,
      padding: EdgeInsets.zero,
    );
  }
}
