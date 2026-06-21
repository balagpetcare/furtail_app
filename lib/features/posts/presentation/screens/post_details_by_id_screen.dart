import 'package:bpa_app/core/theme/typography.dart';
import 'package:flutter/material.dart';

import '../../data/datasources/posts_remote_ds.dart';
import 'post_details_screen.dart';

/// Opens [PostDetailsScreen] after loading post by id (deep links / push).
class PostDetailsByIdScreen extends StatefulWidget {
  final int postId;

  const PostDetailsByIdScreen({super.key, required this.postId});

  @override
  State<PostDetailsByIdScreen> createState() => _PostDetailsByIdScreenState();
}

class _PostDetailsByIdScreenState extends State<PostDetailsByIdScreen> {
  final _ds = PostsRemoteDs();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _ds.getPostById(postId: widget.postId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load post',
                  style: context.appText.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        final post = snapshot.data;
        if (post == null) {
          return const Scaffold(
            body: Center(child: Text('Post not found')),
          );
        }
        return PostDetailsScreen(post: post);
      },
    );
  }
}
