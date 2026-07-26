import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final hero = mediaItems.isNotEmpty ? mediaItems.first : null;
    final endsAt = draft.endsAt ?? draft.deadline;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: _HeroPreview(item: hero),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
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
                const SizedBox(height: 8),
                Text(
                  draft.story.trim().isEmpty
                      ? t.fundraisingPreviewStoryPlaceholder
                      : draft.story.trim(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
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
                      value: '${mediaItems.length}',
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
        borderRadius: BorderRadius.circular(14),
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
    if (item == null) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, size: 48),
      );
    }

    final previewUrl = item!.previewUrl;
    if (previewUrl != null && previewUrl.isNotEmpty) {
      return Image.network(
        previewUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _previewPlaceholder(context),
      );
    }

    if (item!.thumbnailPath != null &&
        item!.thumbnailPath!.isNotEmpty &&
        File(item!.thumbnailPath!).existsSync()) {
      return Image.file(
        File(item!.thumbnailPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _previewPlaceholder(context),
      );
    }

    if (item!.localPath != null &&
        item!.localPath!.isNotEmpty &&
        File(item!.localPath!).existsSync()) {
      if (item!.isDocument) {
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: const Icon(Icons.description_outlined, size: 48),
        );
      }
      return Image.file(
        File(item!.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _previewPlaceholder(context),
      );
    }

    return _previewPlaceholder(context);
  }

  Widget _previewPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        item!.isDocument ? Icons.description_outlined : Icons.image_outlined,
        size: 48,
      ),
    );
  }
}
