import 'package:flutter/material.dart';

/// Inline comment preview for a feed post card.
///
/// Shows up to 3 recent comments as RichText entries and a
/// "View all comments" button.
///
/// The [recentComments] list items are accessed dynamically at runtime
/// to handle varying backend comment shapes (author, text, replyCount).
class PostCardCommentPreview extends StatelessWidget {
  final List<dynamic> recentComments;
  final VoidCallback onViewAll;
  final String Function(dynamic c) commentAuthor;
  final String Function(dynamic c) commentText;
  final int Function(dynamic c) replyCount;

  const PostCardCommentPreview({
    super.key,
    required this.recentComments,
    required this.onViewAll,
    required this.commentAuthor,
    required this.commentText,
    required this.replyCount,
  });

  @override
  Widget build(BuildContext context) {
    if (recentComments.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...recentComments.take(3).map((c) {
            final author = commentAuthor(c);
            final text = commentText(c);
            final replies = replyCount(c);

            if (text.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '$author  ',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: text),
                    if (replies > 0)
                      TextSpan(
                        text: '  ·  $replies replies',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('View all comments'),
            ),
          ),
        ],
      ),
    );
  }
}
