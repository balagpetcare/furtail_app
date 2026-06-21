import 'package:flutter/material.dart';

/// SnackBar helper that keeps the center FAB fixed and visually clean.
///
/// Using [SnackBarBehavior.floating] with a bottom margin prevents the
/// SnackBar from pushing UI elements (like the create-post FAB) upward.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 2),
}) {
  final snack = SnackBar(
    content: Text(message),
    duration: duration,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    backgroundColor: isError ? Colors.red.shade700 : Colors.black87,
  );

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(snack);
}
