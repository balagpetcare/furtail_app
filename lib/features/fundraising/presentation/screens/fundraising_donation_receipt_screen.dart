import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:furtail_app/l10n/app_localizations.dart';

import '../../data/models/fundraising_donation_models.dart';

class FundraisingDonationReceiptScreen extends StatelessWidget {
  const FundraisingDonationReceiptScreen({super.key, required this.record});

  final FundraisingDonationCheckoutRecord record;

  String _formatBdt(BuildContext context, int amount) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return '৳${NumberFormat.decimalPattern(locale).format(amount)}';
  }

  String _formatDate(BuildContext context, DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMMd(locale).add_jm().format(dateTime.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.fundraisingDonationReceiptTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatBdt(context, record.amountMinor),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  record.campaignTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                _ReceiptRow(
                  label: t.fundraisingDonationReceiptReference,
                  value: record.referenceId ?? record.attemptId,
                ),
                _ReceiptRow(
                  label: t.fundraisingDonationReceiptDate,
                  value: _formatDate(context, record.confirmedAt),
                ),
                _ReceiptRow(
                  label: t.fundraisingDonationReceiptVisibility,
                  value: record.isAnonymous
                      ? t.fundraisingDonationVisibilityAnonymous
                      : t.fundraisingDonationVisibilityPublic,
                ),
                if (record.supportMessage.trim().isNotEmpty)
                  _ReceiptRow(
                    label: t.fundraisingDonationReceiptMessage,
                    value: record.supportMessage,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
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
