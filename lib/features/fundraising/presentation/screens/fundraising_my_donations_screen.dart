import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:furtail_app/l10n/app_localizations.dart';

import '../../data/models/fundraising_donation_models.dart';
import '../providers/fundraising_providers.dart';
import 'fundraising_donation_result_screen.dart';

class FundraisingMyDonationsScreen extends ConsumerStatefulWidget {
  const FundraisingMyDonationsScreen({super.key});

  @override
  ConsumerState<FundraisingMyDonationsScreen> createState() =>
      _FundraisingMyDonationsScreenState();
}

class _FundraisingMyDonationsScreenState
    extends ConsumerState<FundraisingMyDonationsScreen> {
  FundraisingDonationCheckoutStatus? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fundraisingDonationCheckoutControllerProvider).initialize();
    });
  }

  String _formatBdt(BuildContext context, int amount) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return '৳${NumberFormat.decimalPattern(locale).format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final controller = ref.watch(fundraisingDonationCheckoutControllerProvider);
    final filtered = controller.history.where((item) {
      if (_filter == null) return true;
      return item.status == _filter;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(t.fundraisingDonationHistoryTitle)),
      body: Column(
        children: [
          SizedBox(
            height: 60,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  selected: _filter == null,
                  label: t.fundraisingDonationFilterAll,
                  onTap: () => setState(() => _filter = null),
                ),
                _FilterChip(
                  selected:
                      _filter ==
                      FundraisingDonationCheckoutStatus.paymentPending,
                  label: t.fundraisingDonationFilterPending,
                  onTap: () => setState(
                    () => _filter =
                        FundraisingDonationCheckoutStatus.paymentPending,
                  ),
                ),
                _FilterChip(
                  selected:
                      _filter == FundraisingDonationCheckoutStatus.succeeded,
                  label: t.fundraisingDonationFilterSucceeded,
                  onTap: () => setState(
                    () => _filter = FundraisingDonationCheckoutStatus.succeeded,
                  ),
                ),
                _FilterChip(
                  selected: _filter == FundraisingDonationCheckoutStatus.failed,
                  label: t.fundraisingDonationFilterFailed,
                  onTap: () => setState(
                    () => _filter = FundraisingDonationCheckoutStatus.failed,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text(t.fundraisingDonationHistoryEmpty))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.campaignTitle),
                          subtitle: Text(
                            '${_formatBdt(context, item.amountMinor)} • ${_statusLabel(t, item.status)}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FundraisingDonationResultScreen(
                                  attemptId: item.attemptId,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(
    AppLocalizations t,
    FundraisingDonationCheckoutStatus status,
  ) {
    return switch (status) {
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
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
