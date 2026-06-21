import 'package:flutter/material.dart';

import 'comments_sheet.dart';

/// Central helper to open the comments UI as a keyboard-safe bottom sheet.
///
/// Use this anywhere there is a "Write comment" input so the sheet slides
/// up from the bottom and never gets hidden behind the keyboard.
Future<T?> showCommentsBottomSheet<T>(
  BuildContext context, {
  required int postId,
  void Function(int newCount)? onCountChanged,
  bool autoFocusComposer = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final height = MediaQuery.of(ctx).size.height;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          top: false,
          child: Material(
            color: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: SizedBox(
              height: height * 0.9,
              child: CommentsSheet(
                postId: postId,
                onCountChanged: onCountChanged,
                autoFocusComposer: autoFocusComposer,
              ),
            ),
          ),
        ),
      );
    },
  );
}
