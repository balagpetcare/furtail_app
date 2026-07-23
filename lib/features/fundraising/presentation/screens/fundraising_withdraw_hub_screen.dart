import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/core/theme/typography.dart';

import '../../data/fundraising_error_mapper.dart';
import '../../data/models/fundraising_models.dart';
import '../../data/models/fundraising_payout_models.dart';
import '../providers/fundraising_providers.dart';
import 'fundraising_common_scaffold.dart';

class FundraisingWithdrawHubScreen extends ConsumerStatefulWidget {
  const FundraisingWithdrawHubScreen({super.key});

  @override
  ConsumerState<FundraisingWithdrawHubScreen> createState() =>
      _FundraisingWithdrawHubScreenState();
}

class _FundraisingWithdrawHubScreenState
    extends ConsumerState<FundraisingWithdrawHubScreen> {
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
    final campaignsAsync = ref.watch(fundraisingMyCampaignsProvider);
    final methodsAsync = ref.watch(fundraisingMyPayoutMethodsProvider);
    final repo = ref.read(fundraisingRepositoryProvider);

    return FundraisingCommonScaffold(
      title: 'Withdraw',
      showCreate: false,
      showFilters: false,
      showVerification: true,
      body: SafeArea(
        child: campaignsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(mapFundraisingError(error))),
          data: (campaigns) {
            if (campaigns.isEmpty) {
              return const _InfoBox(
                title: 'No fundraising campaigns found',
                message:
                    'Create a fundraising campaign first to withdraw collected funds.',
                icon: Icons.volunteer_activism_outlined,
              );
            }

            _campaignId ??= campaigns.first.id;
            final selected = campaigns.firstWhere(
              (campaign) => campaign.id == _campaignId,
              orElse: () => campaigns.first,
            );
            final requestsAsync = ref.watch(
              fundraisingWithdrawRequestsProvider(selected.id),
            );

            return FutureBuilder<FundraisingWithdrawBalanceSummary>(
              future: repo.fetchWithdrawBalanceSummary(campaignId: selected.id),
              builder: (context, snapshot) {
                final balance = snapshot.data;
                final available =
                    balance?.availableMinor ?? selected.stats.availableAmount;
                final pending = balance?.pendingMinor ?? 0;
                final reserved = balance?.reservedMinor ?? 0;

                final existingRequests =
                    requestsAsync.asData?.value ??
                    const <FundraisingWithdrawRequest>[];
                final openRequest = existingRequests.where(
                  (request) => const <String>{
                    'SUBMITTED',
                    'UNDER_REVIEW',
                    'APPROVED',
                    'PROCESSING',
                  }.contains(request.status),
                );
                final hasOpenRequest = openRequest.isNotEmpty;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    _CampaignPicker(
                      campaigns: campaigns,
                      value: selected.id,
                      onChanged: (value) {
                        setState(() {
                          _campaignId = value;
                          _amountCtrl.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _SummaryCard(
                      totalRaised:
                          balance?.totalRaisedMinor ??
                          selected.stats.raisedAmount,
                      pending: pending,
                      reserved: reserved,
                      available: available,
                    ),
                    const SizedBox(height: 12),
                    _SurfaceCard(
                      child: methodsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) => Text(mapFundraisingError(error)),
                        data: (methods) {
                          final activeMethods = methods
                              .where((method) => method.isActive)
                              .toList();
                          if (activeMethods.isEmpty) {
                            return const Text(
                              'Add an active payout method before submitting a withdrawal.',
                            );
                          }
                          _methodId ??= activeMethods
                              .firstWhere(
                                (method) => method.isDefault,
                                orElse: () => activeMethods.first,
                              )
                              .id;
                          return Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Request withdrawal',
                                  style: context.appText.bodyLarge!.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Available is ready to withdraw. Pending is still settling. Reserved is already committed to another withdrawal.',
                                ),
                                if (hasOpenRequest) ...[
                                  const SizedBox(height: 12),
                                  _Banner(
                                    text: reserved > 0
                                        ? 'You already have a withdrawal under review. Reserved balance: ৳$reserved.'
                                        : 'You already have a withdrawal under review.',
                                    bg: const Color(0xFFFFF1F1),
                                    border: const Color(0xFFFFB4B4),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _amountCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Amount (BDT)',
                                    hintText: 'Available: $available',
                                  ),
                                  validator: (value) {
                                    final raw = (value ?? '').trim();
                                    if (raw.isEmpty)
                                      return 'Amount is required';
                                    final parsed = int.tryParse(raw);
                                    if (parsed == null || parsed <= 0) {
                                      return 'Enter a valid amount';
                                    }
                                    if (parsed > available) {
                                      return 'Amount exceeds available balance';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  initialValue: _methodId,
                                  decoration: const InputDecoration(
                                    labelText: 'Payout method',
                                  ),
                                  items: activeMethods
                                      .map(
                                        (method) => DropdownMenuItem<int>(
                                          value: method.id,
                                          child: Text(
                                            '${method.displayName}\n${method.summary}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _methodId = value),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _noteCtrl,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Note (optional)',
                                    hintText:
                                        'Add context for the reviewer if needed',
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _submitting || hasOpenRequest
                                        ? null
                                        : () async {
                                            if (!_formKey.currentState!
                                                .validate()) {
                                              return;
                                            }
                                            setState(() => _submitting = true);
                                            try {
                                              await repo.createWithdrawRequest(
                                                campaignId: selected.id,
                                                amount: int.parse(
                                                  _amountCtrl.text.trim(),
                                                ),
                                                methodId: _methodId!,
                                                note:
                                                    _noteCtrl.text
                                                        .trim()
                                                        .isEmpty
                                                    ? null
                                                    : _noteCtrl.text.trim(),
                                              );
                                              ref.invalidate(
                                                fundraisingWithdrawRequestsProvider(
                                                  selected.id,
                                                ),
                                              );
                                              ref.invalidate(
                                                fundraisingCampaignProvider(
                                                  selected.id,
                                                ),
                                              );
                                              ref.invalidate(
                                                fundraisingMyCampaignsProvider,
                                              );
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Withdrawal submitted.',
                                                  ),
                                                ),
                                              );
                                              _amountCtrl.clear();
                                              _noteCtrl.clear();
                                            } catch (error) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    mapFundraisingError(error),
                                                  ),
                                                ),
                                              );
                                            } finally {
                                              if (mounted) {
                                                setState(
                                                  () => _submitting = false,
                                                );
                                              }
                                            }
                                          },
                                    child: _submitting
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
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
                    const Text(
                      'Recent withdrawal requests',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    requestsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Text(mapFundraisingError(error)),
                      data: (items) {
                        if (items.isEmpty) {
                          return const Text('No withdrawal requests yet.');
                        }
                        return Column(
                          children: items
                              .map((item) => _WithdrawRequestTile(item: item))
                              .toList(),
                        );
                      },
                    ),
                  ],
                );
              },
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

  const _CampaignPicker({
    required this.campaigns,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select campaign',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: value,
            items: campaigns
                .map(
                  (campaign) => DropdownMenuItem<int>(
                    value: campaign.id,
                    child: Text(
                      campaign.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onChanged(value);
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
  final int totalRaised;
  final int pending;
  final int reserved;
  final int available;

  const _SummaryCard({
    required this.totalRaised,
    required this.pending,
    required this.reserved,
    required this.available,
  });

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

    return _SurfaceCard(
      background: const Color(0xFFF6F8FB),
      child: Column(
        children: [
          row('Total raised', totalRaised),
          const SizedBox(height: 6),
          row('Pending', pending),
          const SizedBox(height: 6),
          row('Reserved', reserved),
          const SizedBox(height: 6),
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
    final methodName =
        item.method?.displayName ?? item.method?.label ?? 'Payout method';
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '৳${item.amount}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                item.status,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(methodName, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            item.method?.summary ?? 'Masked payout details on file',
            style: const TextStyle(color: Colors.black54),
          ),
          if ((item.failureReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.failureReason!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
          if (item.timeline.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...item.timeline.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  entry.reason == null || entry.reason!.trim().isEmpty
                      ? '${entry.status} • ${entry.at?.toLocal() ?? item.createdAt.toLocal()}'
                      : '${entry.status} • ${entry.reason}',
                  style: context.appText.bodySmall,
                ),
              ),
            ),
          ],
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

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final Color background;

  const _SurfaceCard({required this.child, this.background = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _InfoBox({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SurfaceCard(
          child: Column(
            children: [
              Icon(icon, size: 44, color: Colors.black54),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
