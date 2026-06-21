import 'package:flutter/material.dart';
import 'package:bpa_app/features/posts/presentation/widgets/comments_sheet.dart';

class FundraisingCommentsScreen extends StatelessWidget {
  final int postId;
  final int commentCount;

  const FundraisingCommentsScreen({
    super.key,
    required this.postId,
    required this.commentCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Comments ($commentCount)')),
      body: SafeArea(
        child: CommentsSheet(postId: postId),
      ),
    );
  }
}