import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:furtail_app/l10n/app_localizations.dart';

import '../../data/models/fundraising_donation_models.dart';

Future<FundraisingDonationDraft?> showFundraisingDonationCheckoutSheet(
  BuildContext context, {
  int initialAmountMinor = 500,
}) {
  return showModalBottomSheet<FundraisingDonationDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) {
      return _FundraisingDonationCheckoutSheet(
        initialAmountMinor: initialAmountMinor,
      );
    },
  );
}

class _FundraisingDonationCheckoutSheet extends StatefulWidget {
  const _FundraisingDonationCheckoutSheet({required this.initialAmountMinor});

  final int initialAmountMinor;

  @override
  State<_FundraisingDonationCheckoutSheet> createState() =>
      _FundraisingDonationCheckoutSheetState();
}

class _FundraisingDonationCheckoutSheetState
    extends State<_FundraisingDonationCheckoutSheet> {
  static const List<int> _quickAmounts = <int>[100, 300, 500, 1000];

  late final TextEditingController _amountController;
  late final TextEditingController _messageController;
  bool _isAnonymous = false;
  bool _consentAccepted = false;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmountMinor.toString(),
    );
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  int get _amountMinor => int.tryParse(_amountController.text.trim()) ?? 0;

  String _formatBdt(BuildContext context, int amount) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return '৳${NumberFormat.decimalPattern(locale).format(amount)}';
  }

  void _submit() {
    final t = AppLocalizations.of(context)!;
    if (_amountMinor <= 0) {
      setState(() {
        _validationMessage = t.fundraisingDonationValidationAmount;
      });
      return;
    }
    if (!_consentAccepted) {
      setState(() {
        _validationMessage = t.fundraisingDonationValidationConsent;
      });
      return;
    }
    Navigator.of(context).pop(
      FundraisingDonationDraft(
        amountMinor: _amountMinor,
        isAnonymous: _isAnonymous,
        supportMessage: _messageController.text.trim(),
        consentAccepted: _consentAccepted,
        paymentMethodLabel: t.fundraisingDonationPaymentMethodOnline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final total = _amountMinor;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.fundraisingDonationCheckoutTitle,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              t.fundraisingDonationCheckoutSubtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _quickAmounts
                  .map(
                    (amount) => ChoiceChip(
                      label: Text(_formatBdt(context, amount)),
                      selected: _amountMinor == amount,
                      onSelected: (_) {
                        setState(() {
                          _amountController.text = amount.toString();
                          _validationMessage = null;
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t.fundraisingDonationAmountLabel,
                prefixText: '৳ ',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _validationMessage = null),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text(t.fundraisingDonationVisibilityPublic),
                  icon: const Icon(Icons.visibility_outlined),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(t.fundraisingDonationVisibilityAnonymous),
                  icon: const Icon(Icons.visibility_off_outlined),
                ),
              ],
              selected: <bool>{_isAnonymous},
              onSelectionChanged: (values) {
                setState(() {
                  _isAnonymous = values.first;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: t.fundraisingDonationMessageLabel,
                hintText: t.fundraisingDonationMessageHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: t.fundraisingDonationPaymentMethodTitle,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE9F3FF),
                  child: Icon(Icons.verified_user_outlined),
                ),
                title: Text(t.fundraisingDonationPaymentMethodOnline),
                subtitle: Text(t.fundraisingDonationPaymentMethodSubtitle),
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: t.fundraisingDonationSummaryTitle,
              child: Column(
                children: [
                  _SummaryRow(
                    label: t.fundraisingDonationSummaryAmount,
                    value: _formatBdt(context, _amountMinor),
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: t.fundraisingDonationSummaryFee,
                    value: _formatBdt(context, 0),
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: t.fundraisingDonationSummaryTotal,
                    value: _formatBdt(context, total),
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              value: _consentAccepted,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(t.fundraisingDonationConsent),
              onChanged: (value) {
                setState(() {
                  _consentAccepted = value ?? false;
                  _validationMessage = null;
                });
              },
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _validationMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.fundraisingDonationCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(t.fundraisingDonationContinue),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyLarge;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}
