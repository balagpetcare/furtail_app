import 'package:flutter/material.dart';

/// A clean placeholder screen with an AppBar, back button, icon, title, and
/// descriptive message. Use it wherever a feature page does not exist yet
/// instead of showing a snackbar.
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Widget? trailing;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.construction_rounded,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: cs.primary.withValues(alpha: 0.25)),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              if (trailing != null) ...[const SizedBox(height: 24), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
