import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/wallet_models.dart';
import '../providers/wallet_providers.dart';

class WalletWithdrawRequestsScreen extends ConsumerWidget {
  const WalletWithdrawRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(walletWithdrawRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw Requests')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(walletWithdrawRequestsProvider);
            ref.invalidate(walletSummaryProvider);
            ref.invalidate(walletTransactionsProvider);
          },
          child: asyncItems.when(
            data: (items) {
              final list = items.cast<WalletWithdrawRequest>();
              if (list.isEmpty) {
                return ListView(
                  padding: EdgeInsets.all(16),
                  children: [_Empty(text: 'No withdraw requests yet')],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final r = list[i];
                  return _RequestTile(r: r);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [Text(e.toString())],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final WalletWithdrawRequest r;
  const _RequestTile({required this.r});

  bool get _canCancel =>
      r.status == 'SUBMITTED' ||
      r.status == 'UNDER_REVIEW' ||
      r.status == 'QUEUED';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EDF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${r.amount} BDT',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  r.method,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              _StatusChip(status: r.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _canCancel
                      ? () async {
                          try {
                            final repo = ref.read(walletRepositoryProvider);
                            await repo.cancelWithdrawRequest(r.id);
                            ref.invalidate(walletWithdrawRequestsProvider);
                            ref.invalidate(walletSummaryProvider);
                            ref.invalidate(walletTransactionsProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Request canceled'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        }
                      : null,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase();
    IconData icon = Icons.info_outline_rounded;
    Color bg = const Color(0xFFF6F8FB);
    Color fg = const Color(0xFF334155);

    if (s == 'TRANSFERRED' || s == 'SUCCESS') {
      icon = Icons.check_circle_outline_rounded;
      bg = const Color(0xFFE7F7EE);
      fg = const Color(0xFF0F766E);
    } else if (s == 'PROCESSING') {
      icon = Icons.sync_rounded;
      bg = const Color(0xFFEAF2FF);
      fg = const Color(0xFF1D4ED8);
    } else if (s == 'QUEUED' || s == 'APPROVED') {
      icon = Icons.schedule_rounded;
      bg = const Color(0xFFFFF7E6);
      fg = const Color(0xFFB45309);
    } else if (s == 'FAILED' || s == 'REJECTED' || s == 'CANCELED') {
      icon = Icons.error_outline_rounded;
      bg = const Color(0xFFFFE8E8);
      fg = const Color(0xFFB91C1C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            s,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});

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
