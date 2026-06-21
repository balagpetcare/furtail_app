import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/fundraising_models.dart';
import '../../data/models/fundraising_payout_models.dart';
import '../providers/fundraising_providers.dart';
import 'fundraising_common_scaffold.dart';

/// Unified Withdraw UI
///
/// Fundraiser can:
/// 1) Select a campaign
/// 2) Select payout method
/// 3) Submit withdraw request
///
/// This uses the existing backend contract:
/// - GET /fundraising/my/campaigns
/// - GET /fundraising/withdraw/requests?campaignId=
/// - POST /fundraising/campaigns/:id/withdraw
class FundraisingWithdrawHubScreen extends ConsumerStatefulWidget {
  const FundraisingWithdrawHubScreen({super.key});

  @override
  ConsumerState<FundraisingWithdrawHubScreen> createState() => _FundraisingWithdrawHubScreenState();
}

class _FundraisingWithdrawHubScreenState extends ConsumerState<FundraisingWithdrawHubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  int? _campaignId;
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
    final myCampaignsAsync = ref.watch(fundraisingMyCampaignsProvider);
    final methodsAsync = ref.watch(fundraisingMyPayoutMethodsProvider);

    return FundraisingCommonScaffold(
      title: 'Withdraw',
      showCreate: false,
      showFilters: false,
      showVerification: true,
      body: SafeArea(
        child: myCampaignsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (campaigns) {
            if (campaigns.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _InfoBox(
                    title: 'No fundraising campaigns found',
                    message: 'Create a fundraising campaign first to withdraw collected funds.',
                    icon: Icons.volunteer_activism,
                  ),
                ],
              );
            }

            // Preselect first campaign
            _campaignId ??= campaigns.first.id;
            final selected = campaigns.firstWhere((c) => c.id == _campaignId, orElse: () => campaigns.first);

            final requestsAsync = ref.watch(fundraisingWithdrawRequestsProvider(selected.id));
            final reqData = requestsAsync.asData?.value;
            final pending = (reqData ?? const <FundraisingWithdrawRequest>[])
                .where((r) => r.status == 'SUBMITTED' || r.status == 'UNDER_REVIEW' || r.status == 'APPROVED')
                .toList();
            final hasPending = pending.isNotEmpty;
            final reserved = pending.fold<int>(0, (sum, r) => sum + r.amount);
            final availableBase = selected.stats.availableAmount;
            final available = (availableBase - reserved) < 0 ? 0 : (availableBase - reserved);
            final requestsLoaded = requestsAsync.asData != null;
            final canCreateRequest = requestsLoaded && !hasPending;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                _CampaignPicker(
                  campaigns: campaigns,
                  value: selected.id,
                  onChanged: (v) {
                    setState(() {
                      _campaignId = v;
                      _amountCtrl.clear();
                    });
                  },
                ),
                const SizedBox(height: 12),
                _SummaryCard(
                  raised: selected.stats.raisedAmount,
                  withdrawn: selected.stats.withdrawnAmount,
                  available: available,
                ),
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
                            const Text('No payout method found.', style: TextStyle(fontWeight: FontWeight.w800)),
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

                      // Preselect default method
                      _methodId ??= active.firstWhere((m) => m.isDefault, orElse: () => active.first).id;

                      return Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Request withdrawal', style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 10),
                            if (!requestsLoaded)
                              _Banner(
                                text: 'Loading your existing withdraw requests… Please wait a moment.',
                                bg: const Color(0xFFFFF7E6),
                                border: const Color(0xFFFFD18A),
                              ),
                            if (hasPending)
                              _Banner(
                                text: reserved > 0
                                    ? 'You already have a pending withdraw request (৳$reserved). Please wait for admin review before submitting another.'
                                    : 'You already have a pending withdraw request. Please wait for admin review before submitting another.',
                                bg: const Color(0xFFFFF1F1),
                                border: const Color(0xFFFFB4B4),
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
                                            campaignId: selected.id,
                                            amount: amount,
                                            methodId: methodId,
                                            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                                          );
                                          ref.invalidate(fundraisingWithdrawRequestsProvider(selected.id));
                                          ref.invalidate(fundraisingCampaignProvider(selected.id));
                                          ref.invalidate(fundraisingMyCampaignsProvider);
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Withdraw request submitted.')),
                                          );
                                          _amountCtrl.clear();
                                          _noteCtrl.clear();
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
                const Text('Recent withdraw requests', style: TextStyle(fontWeight: FontWeight.w900)),
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
            );
          },
        ),
      ),
    );
  }
}

class _CampaignPicker extends StatelessWidget {
  final List<FundraisingCampaign> campaigns;
  final int value;
  final ValueChanged<int> onChanged;

  const _CampaignPicker({required this.campaigns, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select campaign', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: value,
            items: campaigns
                .map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        c.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
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
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          row('Raised', raised),
          const SizedBox(height: 6),
          row('Withdrawn', withdrawn),
          const SizedBox(height: 6),
          row('Available now', available),
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
    final status = item.status;
    final created = item.createdAt;
    final methodName = item.method?.catalog?.name ?? item.method?.label ?? 'Method';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('৳${item.amount}', style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(status, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text(methodName, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          Text(created.toLocal().toString(), style: context.appText.bodySmall!.copyWith(color: Colors.black38)),
          if ((item.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.note!, style: const TextStyle(color: Colors.black87)),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color bg;
  final Color border;
  const _Banner({required this.text, required this.bg, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  const _InfoBox({required this.title, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: Colors.black54),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
