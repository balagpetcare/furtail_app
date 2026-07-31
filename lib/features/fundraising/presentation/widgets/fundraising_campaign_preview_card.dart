import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:furtail_app/core/media/media_url.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_draft_models.dart';
import 'package:furtail_app/features/media/composer/media_draft_item.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

class FundraisingCampaignPreviewCard extends StatelessWidget {
  const FundraisingCampaignPreviewCard({
    super.key,
    required this.draft,
    required this.mediaItems,
  });

  final FundraisingDraftRecovery draft;
  final List<MediaDraftItem> mediaItems;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final money = NumberFormat.decimalPattern('en');
    final mode = draft.fundingMode.trim().toUpperCase();
    final oneTime = mode.isEmpty || mode == 'ONE_TIME';
    final targetMinor = oneTime
        ? (draft.targetAmountMinor ?? draft.suggestedTargetMinor)
        : draft.monthlyGoalMinor;
    final visibleMediaItems = fundraisingPreviewVisibleMediaItems(mediaItems);
    final hero = visibleMediaItems.isNotEmpty ? visibleMediaItems.first : null;
    final hasMediaItems = mediaItems.any(
      (item) => !item.hasFailed && !item.isCancelled,
    );
    final endsAt = draft.endsAt ?? draft.deadline;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hero != null) ...[
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: _HeroPreview(item: hero),
              ),
            ),
            if (visibleMediaItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 88,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    return _MediaPreviewTile(item: visibleMediaItems[index]);
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
                  itemCount: visibleMediaItems.length,
                ),
              ),
            ],
          ] else if (hasMediaItems) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image_not_supported_outlined, size: 42),
                  const SizedBox(height: 8),
                  Text(
                    t.fundraisingValidationMediaBlocking,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    t.fundraisingPendingReviewBadge,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FactChip(
                  label: t.fundraisingFundingModeField,
                  value: oneTime
                      ? t.fundraisingFundingModeOneTime
                      : t.fundraisingFundingModeOngoing,
                ),
                const SizedBox(height: 10),
                Text(
                  draft.title.trim().isEmpty
                      ? t.fundraisingPreviewTitlePlaceholder
                      : draft.title.trim(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (draft.shortDescription.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    draft.shortDescription.trim(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  draft.story.trim().isEmpty
                      ? t.fundraisingPreviewStoryPlaceholder
                      : draft.story.trim(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (draft.whatHappened.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _StorySection(
                    title: 'What happened?',
                    body: draft.whatHappened.trim(),
                  ),
                ],
                if (draft.whyUrgent.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _StorySection(
                    title: 'Why is it urgent?',
                    body: draft.whyUrgent.trim(),
                  ),
                ],
                if (draft.fundUsage.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _StorySection(
                    title: 'How will the funds be used?',
                    body: draft.fundUsage.trim(),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _FactChip(
                      label: oneTime
                          ? t.fundraisingGoalLabel
                          : t.fundraisingMonthlyGoalField,
                      value: targetMinor == null
                          ? t.fundraisingOptional
                          : 'BDT ${money.format(targetMinor)}',
                    ),
                    _FactChip(
                      label: t.fundraisingBeneficiaryLabel,
                      value: draft.beneficiaryName.trim().isEmpty
                          ? t.fundraisingBeneficiaryPlaceholder
                          : draft.beneficiaryName.trim(),
                    ),
                    _FactChip(
                      label: t.fundraisingDurationField,
                      value: oneTime
                          ? (endsAt == null
                                ? t.fundraisingSelectDeadline
                                : DateFormat.yMMMd().format(endsAt))
                          : t.fundraisingOngoingSupportLabel,
                    ),
                    _FactChip(
                      label: t.fundraisingLocationLabel,
                      value: draft.locationText.trim().isEmpty
                          ? t.fundraisingLocationPlaceholder
                          : draft.locationText.trim(),
                    ),
                    _FactChip(
                      label: t.fundraisingEvidenceLabel,
                      value: '${visibleMediaItems.length}',
                    ),
                  ],
                ),
                if (!oneTime && draft.nextReviewAt != null) ...[
                  const SizedBox(height: 16),
                  _FactChip(
                    label: t.fundraisingNextReviewField,
                    value: DateFormat.yMMMd().format(draft.nextReviewAt!),
                  ),
                ],
                if (draft.expenses.any(
                  (entry) => (entry.amountMinor ?? 0) > 0,
                )) ...[
                  const SizedBox(height: 18),
                  Text(
                    t.fundraisingExpenseSummaryTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...draft.expenses
                      .where((entry) => (entry.amountMinor ?? 0) > 0)
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(entry.label)),
                              Text('BDT ${money.format(entry.amountMinor)}'),
                            ],
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StorySection extends StatelessWidget {
  const _StorySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _HeroPreview extends StatelessWidget {
  const _HeroPreview({this.item});

  final MediaDraftItem? item;

  @override
  Widget build(BuildContext context) {
    return _buildMediaPreview(context, item, fit: BoxFit.cover);
  }
}

class _MediaPreviewTile extends StatelessWidget {
  const _MediaPreviewTile({required this.item});

  final MediaDraftItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildMediaPreview(context, item, fit: BoxFit.cover),
      ),
    );
  }
}

Widget _buildMediaPreview(
  BuildContext context,
  MediaDraftItem? item, {
  required BoxFit fit,
}) {
  if (item == null) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, size: 48),
    );
  }

  if (item.isDocument) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_outlined, size: 48),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              item.fileName,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  final thumbPath = item.thumbnailPath?.trim();
  if (thumbPath != null &&
      thumbPath.isNotEmpty &&
      File(thumbPath).existsSync()) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(thumbPath),
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              _previewPlaceholder(context, item),
        ),
        if (item.isVideo)
          const Center(child: Icon(Icons.play_circle_fill_rounded, size: 42)),
      ],
    );
  }

  final localPath = item.localPath?.trim();
  if (localPath != null &&
      localPath.isNotEmpty &&
      File(localPath).existsSync() &&
      !item.isVideo) {
    return Image.file(
      File(localPath),
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          _previewPlaceholder(context, item),
    );
  }

  final remoteThumb = fundraisingMediaPreviewNetworkUrl(item);
  if (remoteThumb != null && remoteThumb.isNotEmpty) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FurtailCachedImage(
          imageUrl: MediaUrl.normalize(remoteThumb),
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          placeholder: _previewPlaceholder(context, item),
          errorWidget: _previewPlaceholder(context, item),
        ),
        if (item.isVideo)
          const Center(child: Icon(Icons.play_circle_fill_rounded, size: 42)),
      ],
    );
  }

  return _previewPlaceholder(context, item);
}

@visibleForTesting
List<MediaDraftItem> fundraisingPreviewVisibleMediaItems(
  List<MediaDraftItem> items,
) {
  return items.where(_canRenderPreviewForItem).toList(growable: false);
}

@visibleForTesting
String? fundraisingMediaPreviewNetworkUrl(MediaDraftItem item) {
  if (item.isDocument) return null;
  if (item.isVideo) {
    final remoteThumb = item.remoteThumbnailUrl?.trim();
    if (remoteThumb != null && remoteThumb.isNotEmpty) {
      return MediaUrl.normalize(remoteThumb);
    }
    return null;
  }

  final previewUrl = item.previewUrl?.trim();
  if (previewUrl != null && previewUrl.isNotEmpty) {
    return MediaUrl.normalize(previewUrl);
  }
  return null;
}

bool _canRenderPreviewForItem(MediaDraftItem item) {
  if (item.hasFailed || item.isCancelled) return false;
  if (item.isDocument) return true;

  final thumbPath = item.thumbnailPath?.trim();
  if (thumbPath != null &&
      thumbPath.isNotEmpty &&
      File(thumbPath).existsSync()) {
    return true;
  }

  // This card has no video-frame renderer of its own — a video is only
  // ever shown via an extracted thumbnail frame (checked above) or a
  // server-generated remote thumbnail (checked below). A raw local video
  // file, or merely being uploaded (`remoteMediaId != null`), is not by
  // itself a usable preview source: counting it here previously inflated
  // the "Evidence" count past what `_buildMediaPreview` could actually
  // render, silently leaving a placeholder where a real thumbnail was
  // expected.
  if (item.isVideo) {
    final remoteThumb = fundraisingMediaPreviewNetworkUrl(item);
    return remoteThumb != null && remoteThumb.isNotEmpty;
  }

  final localPath = item.localPath?.trim();
  if (localPath != null &&
      localPath.isNotEmpty &&
      File(localPath).existsSync()) {
    return true;
  }

  final remoteThumb = fundraisingMediaPreviewNetworkUrl(item);
  return remoteThumb != null && remoteThumb.isNotEmpty;
}

Widget _previewPlaceholder(BuildContext context, MediaDraftItem item) {
  return Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: Icon(
      item.isDocument
          ? Icons.description_outlined
          : item.isVideo
          ? Icons.play_circle_outline_rounded
          : Icons.image_outlined,
      size: 48,
    ),
  );
}
