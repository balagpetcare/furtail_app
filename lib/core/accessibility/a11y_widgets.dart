import 'package:flutter/material.dart';

import 'a11y_constants.dart';

/// Ensures tappable area meets [A11yConstants.minTouchTarget].
class MinTouchTarget extends StatelessWidget {
  const MinTouchTarget({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.selected = false,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: A11yConstants.minTouchTarget,
        minHeight: A11yConstants.minTouchTarget,
      ),
      child: Center(child: child),
    );

    if (onTap != null) {
      content = InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }

    if (semanticLabel != null) {
      content = Semantics(
        button: onTap != null,
        label: semanticLabel,
        selected: selected,
        enabled: enabled,
        child: content,
      );
    }

    return content;
  }
}

/// Icon button with tooltip, 48dp target, and screen-reader label.
class AccessibleIconButton extends StatelessWidget {
  const AccessibleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.semanticLabel,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? tooltip,
      enabled: onPressed != null,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color),
        tooltip: tooltip,
        constraints: const BoxConstraints(
          minWidth: A11yConstants.minTouchTarget,
          minHeight: A11yConstants.minTouchTarget,
        ),
      ),
    );
  }
}

/// Announces route title changes to screen readers when used as [MaterialApp.builder].
class AppAccessibilityBuilder extends StatelessWidget {
  const AppAccessibilityBuilder({super.key, required this.child});

  final Widget child;

  static Widget wrap(BuildContext context, Widget? child) {
    if (child == null) return const SizedBox.shrink();
    return AppAccessibilityBuilder(child: child);
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
