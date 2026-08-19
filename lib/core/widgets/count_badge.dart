import 'package:flutter/material.dart';

/// Shared unread/pending-count badge used across the app's social surfaces
/// (Home top bar's Notifications/Messages icons, the Friends hub's Requests
/// tab) so every count badge formats and positions itself the same way.
/// Renders nothing when [count] is 0 — callers never need their own
/// `isLabelVisible` check.
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    required this.child,
    this.backgroundColor,
    this.textColor,
  });

  final int count;
  final Widget child;

  /// Overrides for contexts where the badge sits on a colored surface (e.g.
  /// a Furtail-blue AppBar) and needs to stay legible against it. Defaults
  /// to the theme's own badge colors when omitted.
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : count.toString()),
      offset: const Offset(-4, 4),
      backgroundColor: backgroundColor,
      textColor: textColor,
      child: child,
    );
  }
}
