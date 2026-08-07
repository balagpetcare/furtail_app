import 'package:flutter/material.dart';

import '../../../../core/auth/session_recovery.dart';

/// Compact, friendly error state for a settings section whose data source
/// (typically Central Auth) failed to load — never the whole page blank,
/// never a raw backend message. Central Auth failures are scoped to their
/// own section only: other sections must keep working independently.
class SectionErrorState extends StatelessWidget {
  const SectionErrorState({
    super.key,
    required this.error,
    required this.onRetry,
    this.title = 'This section could not be loaded',
  });

  final Object error;
  final VoidCallback onRetry;
  final String title;

  /// Never surfaces a raw backend/exception message — only the vetted
  /// [SessionRecoveryException] text, or a generic fallback.
  static String friendlyMessage(Object error) {
    if (error is SessionRecoveryException) return error.message;
    return 'Something went wrong loading this section. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 40, color: colors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            friendlyMessage(error),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
