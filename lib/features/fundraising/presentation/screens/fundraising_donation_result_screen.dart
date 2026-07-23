import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:furtail_app/core/services/share_service.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

import '../../data/models/fundraising_donation_models.dart';
import '../providers/fundraising_providers.dart';
import 'fundraising_donation_receipt_screen.dart';

class FundraisingDonationResultScreen extends ConsumerWidget {
  const FundraisingDonationResultScreen({super.key, required this.attemptId});

  final String attemptId;

  String _formatBdt(BuildContext context, int amount) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return '৳${NumberFormat.decimalPattern(locale).format(amount)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(fundraisingDonationCheckoutControllerProvider);
    final record = controller.history
        .where((item) => item.attemptId == attemptId)
        .cast<FundraisingDonationCheckoutRecord?>()
        .firstWhere((item) => item != null, orElse: () => null);
    final t = AppLocalizations.of(context)!;

    if (record == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(t.fundraisingDonationMissingRecord)),
      );
    }

    final isSuccess =
        record.status == FundraisingDonationCheckoutStatus.succeeded;
    final isHold =
        record.status == FundraisingDonationCheckoutStatus.onHoldReview;
    final canRetry =
        record.status == FundraisingDonationCheckoutStatus.failed ||
        record.status == FundraisingDonationCheckoutStatus.cancelled ||
        record.status == FundraisingDonationCheckoutStatus.expired;

    return Scaffold(
      appBar: AppBar(title: Text(t.fundraisingDonationResultTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isSuccess
                    ? const Color(0xFFE9F8EF)
                    : const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: Icon(
                      isSuccess
                          ? Icons.check_circle_outline
                          : isHold
                          ? Icons.hourglass_top_rounded
                          : Icons.error_outline_rounded,
                      size: 34,
                      color: isSuccess
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isSuccess
                        ? t.fundraisingDonationSuccessTitle
                        : isHold
                        ? t.fundraisingDonationHoldTitle
                        : t.fundraisingDonationFailedTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isSuccess
                        ? t.fundraisingDonationSuccessSubtitle
                        : isHold
                        ? t.fundraisingDonationHoldSubtitle
                        : (record.failure?.message ??
                              t.fundraisingDonationFailedSubtitle),
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _DetailCard(
              child: Column(
                children: [
                  _ResultRow(
                    label: t.fundraisingDonationSummaryAmount,
                    value: _formatBdt(context, record.amountMinor),
                  ),
                  _ResultRow(
                    label: t.fundraisingDonationCampaignLabel,
                    value: record.campaignTitle,
                  ),
                  _ResultRow(
                    label: t.fundraisingDonationReceiptReference,
                    value: record.referenceId ?? record.attemptId,
                  ),
                  _ResultRow(
                    label: t.fundraisingDonationReceiptDate,
                    value:
                        DateFormat.yMMMMd(
                          Localizations.localeOf(context).toLanguageTag(),
                        ).add_jm().format(
                          (record.confirmedAt ?? record.updatedAt).toLocal(),
                        ),
                  ),
                  _ResultRow(
                    label: t.fundraisingDonationReceiptVisibility,
                    value: record.isAnonymous
                        ? t.fundraisingDonationVisibilityAnonymous
                        : t.fundraisingDonationVisibilityPublic,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (isSuccess || isHold)
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          FundraisingDonationReceiptScreen(record: record),
                    ),
                  );
                },
                child: Text(t.fundraisingDonationViewReceipt),
              ),
            if (isSuccess || isHold) const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () {
                ShareService.share(
                  context,
                  type: 'fundraising',
                  id: record.campaignId,
                );
              },
              child: Text(t.fundraisingDonationShareCampaign),
            ),
            if (canRetry) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final retried = await ref
                      .read(fundraisingDonationCheckoutControllerProvider)
                      .retryCheckout(record.attemptId);
                  if (!context.mounted || retried == null) return;
                  final opened = await ref
                      .read(fundraisingDonationCheckoutControllerProvider)
                      .openProvider(retried.attemptId);
                  if (!context.mounted || !opened) return;
                  await Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => FundraisingDonationProcessingScreen(
                        attemptId: retried.attemptId,
                      ),
                    ),
                  );
                },
                child: Text(t.fundraisingDonationRetry),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: Text(t.fundraisingDonationDone),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class FundraisingDonationProcessingScreen extends ConsumerStatefulWidget {
  const FundraisingDonationProcessingScreen({
    super.key,
    required this.attemptId,
  });

  final String attemptId;

  @override
  ConsumerState<FundraisingDonationProcessingScreen> createState() =>
      _FundraisingDonationProcessingScreenState();
}

class _FundraisingDonationProcessingScreenState
    extends ConsumerState<FundraisingDonationProcessingScreen>
    with WidgetsBindingObserver {
  bool _navigatedToResult = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(fundraisingDonationCheckoutControllerProvider)
          .initialize();
      await ref
          .read(fundraisingDonationCheckoutControllerProvider)
          .refreshCheckout(widget.attemptId);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(fundraisingDonationCheckoutControllerProvider)
          .refreshCheckout(widget.attemptId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(fundraisingDonationCheckoutControllerProvider);
    final record = controller.history
        .where((item) => item.attemptId == widget.attemptId)
        .cast<FundraisingDonationCheckoutRecord?>()
        .firstWhere((item) => item != null, orElse: () => null);
    final t = AppLocalizations.of(context)!;

    if (record == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(t.fundraisingDonationMissingRecord)),
      );
    }

    if (record.isTerminal && !_navigatedToResult) {
      _navigatedToResult = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                FundraisingDonationResultScreen(attemptId: widget.attemptId),
          ),
        );
      });
    }

    final statusLabel = switch (record.status) {
      FundraisingDonationCheckoutStatus.created =>
        t.fundraisingDonationStatusCreated,
      FundraisingDonationCheckoutStatus.paymentPending =>
        t.fundraisingDonationStatusPending,
      FundraisingDonationCheckoutStatus.processing =>
        t.fundraisingDonationStatusProcessing,
      FundraisingDonationCheckoutStatus.succeeded =>
        t.fundraisingDonationStatusSucceeded,
      FundraisingDonationCheckoutStatus.failed =>
        t.fundraisingDonationStatusFailed,
      FundraisingDonationCheckoutStatus.cancelled =>
        t.fundraisingDonationStatusCancelled,
      FundraisingDonationCheckoutStatus.expired =>
        t.fundraisingDonationStatusExpired,
      FundraisingDonationCheckoutStatus.onHoldReview =>
        t.fundraisingDonationStatusOnHold,
    };

    return Scaffold(
      appBar: AppBar(title: Text(t.fundraisingDonationProcessingTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 24),
              Text(
                t.fundraisingDonationProcessingHeadline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                statusLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (record.failure?.message != null) ...[
                const SizedBox(height: 12),
                Text(
                  record.failure!.message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const Spacer(),
              if (record.redirectUrl != null &&
                  record.status != FundraisingDonationCheckoutStatus.succeeded)
                FilledButton(
                  onPressed: () async {
                    await ref
                        .read(fundraisingDonationCheckoutControllerProvider)
                        .openProvider(widget.attemptId);
                  },
                  child: Text(t.fundraisingDonationOpenProvider),
                ),
              if (record.redirectUrl != null) const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () async {
                  await ref
                      .read(fundraisingDonationCheckoutControllerProvider)
                      .refreshCheckout(widget.attemptId);
                },
                child: Text(t.fundraisingDonationCheckStatus),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await ref
                      .read(fundraisingDonationCheckoutControllerProvider)
                      .markCancelled(widget.attemptId);
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => FundraisingDonationResultScreen(
                        attemptId: widget.attemptId,
                      ),
                    ),
                  );
                },
                child: Text(t.fundraisingDonationCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
