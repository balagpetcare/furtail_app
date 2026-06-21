import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/fundraising_models.dart';
import '../../data/models/fundraising_payout_models.dart';
import '../providers/fundraising_providers.dart';

import 'fundraising_common_scaffold.dart';

/// Create a withdraw request for a campaign.
///
/// Phase C: Withdraw/Payout.
class FundraisingWithdrawRequestScreen extends ConsumerStatefulWidget {
  final FundraisingCampaign campaign;
  const FundraisingWithdrawRequestScreen({super.key, required this.campaign});

  @override
  ConsumerState<FundraisingWithdrawRequestScreen> createState() => _FundraisingWithdrawRequestScreenState();
}

class _FundraisingWithdrawRequestScreenState extends ConsumerState<FundraisingWithdrawRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int? _methodId;
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    final methodsAsync = ref.watch(fundraisingMyPayoutMethodsProvider);
    final requestsAsync = ref.watch(fundraisingWithdrawRequestsProvider(c.id));
    // UI safety: if there is already a pending withdraw request for this campaign,
    // we disable creating another one (backend enforces this too). We also compute
    // a "reserved" amount from pending requests so the UI shows a realistic max.
    final reqData = requestsAsync.asData?.value;
    final pending = (reqData ?? const <FundraisingWithdrawRequest>[])
        .where((r) => r.status == 'SUBMITTED' || r.status == 'UNDER_REVIEW' || r.status == 'APPROVED')
        .toList();
    final hasPending = pending.isNotEmpty;
    final reserved = pending.fold<int>(0, (sum, r) => sum + r.amount);
    final availableBase = c.stats.availableAmount;
    final available = (availableBase - reserved) < 0 ? 0 : (availableBase - reserved);
    final requestsLoaded = requestsAsync.asData != null;
    final canCreateRequest = requestsLoaded && !hasPending;

    return FundraisingCommonScaffold(
      title: 'Withdraw Request',
      showCreate: false,
      showFilters: false,
      showVerification: true,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            _SummaryCard(raised: c.stats.raisedAmount, withdrawn: c.stats.withdrawnAmount, available: available),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEAEAEA)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: methodsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(e.toString()),
                data: (methods) {
                  final active = methods.where((m) => m.isActive).toList();
                  if (active.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No payout method found.',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        const Text('Please add a payout method first from Payout Methods screen.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Go back'),
                        ),
                      ],
                    );
                  }

                  // Preselect default
                  _methodId ??= active.firstWhere((m) => m.isDefault, orElse: () => active.first).id;

                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Request withdrawal', style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        if (!requestsLoaded)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7E6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFD18A)),
                            ),
                            child: const Text(
                              'Loading your existing withdraw requests… Please wait a moment.',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        if (hasPending)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFB4B4)),
                            ),
                            child: Text(
                              reserved > 0
                                  ? 'You already have a pending withdraw request (৳$reserved). Please wait for admin review before submitting another.'
                                  : 'You already have a pending withdraw request. Please wait for admin review before submitting another.',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Amount (BDT)',
                            hintText: 'Max: $available',
                          ),
                          validator: (v) {
                            final raw = (v ?? '').trim();
                            if (raw.isEmpty) return 'Amount is required';
                            final n = int.tryParse(raw);
                            if (n == null || n <= 0) return 'Enter a valid amount';
                            if (n > available) return 'Amount exceeds available balance';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _methodId,
                          decoration: const InputDecoration(labelText: 'Payout method'),
                          items: active
                              .map((m) => DropdownMenuItem(
                                    value: m.id,
                                    child: Text(m.displayName),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _methodId = v),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _noteCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                            hintText: 'Explain why you need to withdraw now',
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: (_submitting || !canCreateRequest)
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) return;
                                    setState(() => _submitting = true);
                                    try {
                                      final repo = ref.read(fundraisingRepositoryProvider);
                                      final amount = int.parse(_amountCtrl.text.trim());
                                      final methodId = _methodId!;
                                      await repo.createWithdrawRequest(
                                        campaignId: c.id,
                                        amount: amount,
                                        methodId: methodId,
                                        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                                      );
                                      ref.invalidate(fundraisingWithdrawRequestsProvider(c.id));
                                      ref.invalidate(fundraisingCampaignProvider(c.id));
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Withdraw request submitted.')),
                                      );
                                      Navigator.pop(context, true);
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    } finally {
                                      if (mounted) setState(() => _submitting = false);
                                    }
                                  },
                            child: _submitting
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Submit request'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text('Your recent withdraw requests', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            requestsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(e.toString()),
              data: (items) {
                if (items.isEmpty) return const Text('No requests yet.');
                return Column(
                  children: items.map((r) => _WithdrawRequestTile(item: r)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int raised;
  final int withdrawn;
  final int available;

  const _SummaryCard({required this.raised, required this.withdrawn, required this.available});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, int value) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text('৳$value', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          row('Raised', raised),
          const SizedBox(height: 6),
          row('Withdrawn', withdrawn),
          const Divider(height: 18),
          row('Available', available),
        ],
      ),
    );
  }
}

class _WithdrawRequestTile extends StatelessWidget {
  final FundraisingWithdrawRequest item;
  const _WithdrawRequestTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final m = item.method;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('৳${item.amount}', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(item.status, style: Theme.of(context).textTheme.bodySmall),
                if ((m?.displayName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(m!.displayName, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          Text(
            '${item.createdAt.year}-${item.createdAt.month.toString().padLeft(2, '0')}-${item.createdAt.day.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
