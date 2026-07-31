import 'package:flutter/material.dart';

class DonateNowBar extends StatelessWidget {
  const DonateNowBar({
    super.key,
    required this.onDonate,
    this.isLoading = false,
    this.label = 'Donate Now',
    this.disabledMessage,
  });

  final VoidCallback? onDonate;
  final bool isLoading;
  final String label;
  final String? disabledMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDonate == null &&
                disabledMessage != null &&
                disabledMessage!.trim().isNotEmpty) ...[
              Text(
                disabledMessage!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton.icon(
                onPressed: isLoading ? null : onDonate,
                icon: isLoading
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.volunteer_activism_rounded),
                label: Text(label),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF6C945),
                  foregroundColor: const Color(0xFF211600),
                  disabledBackgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                  disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
