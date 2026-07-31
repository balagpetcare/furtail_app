import 'package:furtail_app/features/media/composer/media_draft_item.dart';

/// Pure, side-effect-free result of validating a fundraiser's media items.
///
/// Shared by [MediaComposerController] and presentational widgets/tests so
/// business rules for "can this fundraiser continue" live in exactly one
/// place.
class FundraisingMediaValidationResult {
  const FundraisingMediaValidationResult({
    required this.hasAnyItem,
    required this.hasFailedItems,
    required this.hasPendingItems,
    required this.canContinue,
    required this.failedItemIds,
    required this.validationReason,
  });

  final bool hasAnyItem;
  final bool hasFailedItems;
  final bool hasPendingItems;
  final bool canContinue;
  final List<String> failedItemIds;
  final String? validationReason;
}

/// Evaluates [items] against fundraiser media rules without touching the
/// filesystem, network, or any controller state.
FundraisingMediaValidationResult evaluateFundraisingMedia(
  List<MediaDraftItem> items,
) {
  final hasAnyItem = items.isNotEmpty;
  final failedItems = items.where((item) => item.hasFailed).toList();
  final hasFailedItems = failedItems.isNotEmpty;
  final hasPendingItems = items.any(
    (item) =>
        item.state == MediaDraftState.local ||
        item.isUploading ||
        item.isPreparing ||
        item.state == MediaDraftState.processing,
  );
  final canContinue = hasAnyItem && !hasFailedItems && !hasPendingItems;

  String? validationReason;
  if (!hasAnyItem) {
    validationReason = 'Add at least one photo, video, or document.';
  } else if (hasFailedItems) {
    validationReason =
        failedItems.first.errorMessage ??
        'Retry or remove failed uploads before continuing.';
  } else if (hasPendingItems) {
    validationReason = 'Wait for uploads to finish before continuing.';
  }

  return FundraisingMediaValidationResult(
    hasAnyItem: hasAnyItem,
    hasFailedItems: hasFailedItems,
    hasPendingItems: hasPendingItems,
    canContinue: canContinue,
    failedItemIds: failedItems.map((item) => item.id).toList(),
    validationReason: validationReason,
  );
}
