import 'package:flutter/material.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_create_wizard_widgets.dart';
import 'package:furtail_app/features/media/composer/fundraising_media_validation.dart';
import 'package:furtail_app/features/media/composer/media_draft_item.dart';

/// Presentational "needs attention" panel for a failed media item.
///
/// Receives immutable media state and callbacks only — no controller, no
/// filesystem/network access — so it can be pumped in a widget test without
/// booting any media infrastructure.
class FundraisingMediaNeedsAttentionPanel extends StatelessWidget {
  const FundraisingMediaNeedsAttentionPanel({
    super.key,
    required this.items,
    required this.title,
    required this.retryLabel,
    required this.removeLabel,
    required this.blockingFallbackMessage,
    required this.onRetry,
    required this.onRemove,
  });

  final List<MediaDraftItem> items;
  final String title;
  final String retryLabel;
  final String removeLabel;
  final String blockingFallbackMessage;
  final void Function(String itemId) onRetry;
  final void Function(String itemId) onRemove;

  @override
  Widget build(BuildContext context) {
    final validation = evaluateFundraisingMedia(items);
    if (!validation.hasFailedItems) {
      return const SizedBox.shrink();
    }
    final failedId = validation.failedItemIds.first;
    final failedItem = items.firstWhere((item) => item.id == failedId);
    final message =
        '${failedItem.fileName}: '
        '${failedItem.errorMessage?.trim().isNotEmpty == true ? failedItem.errorMessage!.trim() : blockingFallbackMessage}';

    return FundraisingSectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FundraisingInlineMessage(
            variant: FundraisingInlineMessageVariant.danger,
            icon: Icons.error_outline_rounded,
            message: message,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onRetry(failedItem.id),
                  child: Text(retryLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onRemove(failedItem.id),
                  child: Text(removeLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
