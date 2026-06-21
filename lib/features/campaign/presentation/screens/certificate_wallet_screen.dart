import 'package:flutter/material.dart';
import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/core/theme/typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/campaign_models.dart';
import '../providers/campaign_providers.dart';
import '../utils/campaign_health_utils.dart';
import '../widgets/digital_vaccination_card_widget.dart';
import 'certificate_viewer_screen.dart';
import 'qr_verification_screen.dart';

/// All issued vaccination certificates for the logged-in user.
class CertificateWalletScreen extends ConsumerWidget {
  const CertificateWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(vaccinationRecordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificate Wallet'),
        backgroundColor: context.colorScheme.primary,
        foregroundColor: context.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Verify certificate',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QrVerificationScreen()),
            ),
          ),
        ],
      ),
      body: recordsAsync.when(
        data: (records) {
          final wallet = recordsWithCertificates(records);
          if (wallet.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Your wallet is empty. Certificates appear here after campaign vaccinations are completed and linked to your account.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(vaccinationRecordsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: const Color(0xFFE8F1FB),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet_rounded, color: context.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${wallet.length} certificate${wallet.length == 1 ? '' : 's'} · Tap a card to view, share, or download PDF.',
                            style: context.appText.bodyMedium!,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...wallet.map((r) {
                  return DigitalVaccinationCardWidget(
                    record: r,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CertificateViewerScreen(token: r.certificateToken!),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Text(
                  'Issued between ${ _range(wallet) }',
                  textAlign: TextAlign.center,
                  style: context.appText.bodySmall!.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }

  String _range(List<VaccinationRecord> wallet) {
    final dates = wallet
        .map((r) => r.administeredAt)
        .whereType<DateTime>()
        .toList()
      ..sort();
    if (dates.isEmpty) return '—';
    final fmt = DateFormat('MMM yyyy');
    if (dates.length == 1) return fmt.format(dates.first);
    return '${fmt.format(dates.first)} – ${fmt.format(dates.last)}';
  }
}
