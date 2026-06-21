import 'package:flutter/material.dart';

import 'package:bpa_app/core/theme/typography.dart';
import 'package:bpa_app/core/constants/app_colors.dart';
import 'package:bpa_app/core/services/share_service.dart';
import 'package:bpa_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:bpa_app/features/posts/presentation/widgets/comments_sheet.dart';

/// Feed-style reactions (Paw/Comment/Share) to match Home feed UI.
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
  State<FundraisingReactionsSection> createState() => _FundraisingReactionsSectionState();
}

class _FundraisingReactionsSectionState extends State<FundraisingReactionsSection> {
  final _postsDs = PostsRemoteDs();
  late bool _liked;
  late int _likes;

  @override
  void initState() {
    super.initState();
    _liked = widget.initialLikedByMe;
    _likes = widget.initialLikeCount;
  }

  Future<void> _toggleLike() async {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_likes Paws · ${widget.commentCount} comments · 0 shares',
          style: context.appText.bodySmall!.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _ReactionButton(
                icon: _liked ? Icons.pets : Icons.pets_outlined,
                label: 'Paw',
                selected: _liked,
                onTap: _toggleLike,
              ),
            ),
            Expanded(
              child: _ReactionButton(
                icon: Icons.comment_outlined,
                label: 'Comment',
                onTap: _openComments,
              ),
            ),
            Expanded(
              child: _ReactionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: () {
                  ShareService.share(
                    context,
                    type: 'fundraising',
                    id: widget.fundraisingId,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  const _ReactionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppColors.donateBlue : Colors.black87,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.donateBlue : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
