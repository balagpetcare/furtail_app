import 'package:flutter/material.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/presentation/widgets/comments_bottom_sheet.dart';

/// Shows the latest comment inline + a "View All Comments" button.
class FundraisingInlineCommentsPreview extends StatelessWidget {
  final int postId;
  final int commentCount;

  const FundraisingInlineCommentsPreview({
    super.key,
    required this.postId,
    required this.commentCount,
  });

  void _openAll(BuildContext context) {
    showCommentsBottomSheet(
      context,
      postId: postId,
      autoFocusComposer: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final postsDs = PostsRemoteDs();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder(
            future: postsDs.listComments(postId, limit: 1),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Container(height: 16, color: Colors.black12);
              }
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return const Text('No comments yet');
              }
              final c = list.first;
              return RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black87, height: 1.35),
                  children: [
                    TextSpan(
                      text: '${c.author.name}: ',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: c.text),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openAll(context),
              child: Text('View All Comments ($commentCount)'),
            ),
          ),
        ],
      ),
    );
  }
}
