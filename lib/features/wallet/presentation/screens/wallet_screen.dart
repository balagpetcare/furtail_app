import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/wallet_providers.dart';
import 'package:bpa_app/features/fundraising/presentation/screens/fundraising_withdraw_hub_screen.dart';
import 'wallet_withdraw_screen.dart';
import 'wallet_withdraw_requests_screen.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(walletSummaryProvider);
    final txAsync = ref.watch(walletTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).popUntil((r) => r.isFirst);
            }
          },
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(walletSummaryProvider);
            ref.invalidate(walletTransactionsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              summaryAsync.when(
                data: (w) => _SummaryCard(
                  currency: w.currency,
                  balance: w.balance,
                  available: w.availableBalance,
                  pending: w.pendingBalance,
                  locked: w.lockedBalance,
                ),
                loading: () => const _SkeletonCard(),
                error: (e, _) => _ErrorCard(message: e.toString()),
              ),
              const SizedBox(height: 14),
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WalletWithdrawScreen(),
                          ),
                        );
                        ref.invalidate(walletSummaryProvider);
                        ref.invalidate(walletTransactionsProvider);
                        ref.invalidate(walletWithdrawRequestsProvider);
                      },
                      icon: const Icon(Icons.south_west_rounded),
                      label: const Text('Withdraw'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const WalletWithdrawRequestsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: const Text('Requests'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FundraisingWithdrawHubScreen(),
                    ),
                  );
                  // Refresh wallet after returning (withdraw may have reserved funds)
                  ref.invalidate(walletSummaryProvider);
                  ref.invalidate(walletTransactionsProvider);
                  ref.invalidate(walletWithdrawRequestsProvider);
                },
                icon: const Icon(Icons.volunteer_activism_rounded),
                label: const Text('Fundraising Withdraw'),
              ),

              const SizedBox(height: 14),
              Text('Activity', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              txAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const _EmptyState(text: 'No wallet activity yet');
                  }
                  return Column(
                    children: items
                        .map(
                          (t) => _TxTile(
                            title: '${t.type} • ${t.status}',
                            subtitle:
                                t.note ??
                                (t.sourceType != null
                                    ? '${t.sourceType} #${t.sourceId ?? ''}'
                                    : ''),
                            trailing: t.amount,
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => _ErrorCard(message: e.toString()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String currency;
  final String balance;
  final String available;
  final String pending;
  final String locked;
  const _SummaryCard({
    required this.currency,
    required this.balance,
    required this.available,
    required this.pending,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Balance', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            '$balance $currency',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  title: 'Available',
                  value: '$available $currency',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(title: 'Pending', value: '$pending $currency'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(title: 'Reserved', value: '$locked $currency'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String title;
  final String value;
  const _MiniStat({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  const _TxTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EDF4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            trailing,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F6),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD7D7)),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text),
    );
  }
}
