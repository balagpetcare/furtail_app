import 'package:bpa_app/core/analytics/analytics_provider.dart';
import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/core/theme/typography.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../providers/campaign_providers.dart';
import '../providers/smart_campaign_providers.dart';

import 'campaign_benefits_screen.dart';
import 'campaign_geo_preferences_page.dart';
import 'campaign_history_screen.dart';
import 'campaign_list_page.dart';
import 'campaign_analytics_page.dart';
import 'campaign_performance_dashboard_page.dart';
import 'campaign_ticket_lookup_page.dart';

import 'certificate_wallet_screen.dart';

import 'digital_health_card_screen.dart';

import 'my_campaigns_screen.dart';

import 'qr_verification_screen.dart';

import 'upcoming_vaccinations_screen.dart';

import 'vaccination_records_screen.dart';

import 'vaccination_reminders_screen.dart';

import 'vaccination_timeline_screen.dart';



class CampaignHubScreen extends ConsumerWidget {

  const CampaignHubScreen({super.key});



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final summaryAsync = ref.watch(campaignSummaryProvider);
    ref.watch(smartVaccinationReminderSyncProvider);



    return Scaffold(

      appBar: AppBar(

        title: const Text('Vaccination Campaign'),

        backgroundColor: context.colorScheme.primary,

        foregroundColor: context.colorScheme.onPrimary,

      ),

      body: RefreshIndicator(

        onRefresh: () async {

          ref.invalidate(campaignSummaryProvider);

          ref.invalidate(myCampaignBookingsProvider);

          ref.invalidate(vaccinationRecordsProvider);

          ref.invalidate(upcomingVaccinationsProvider);

        },

        child: ListView(

          padding: const EdgeInsets.all(16),

          children: [

            summaryAsync.when(

              data: (s) => _ImportBanner(summary: s, ref: ref),

              loading: () => const SizedBox.shrink(),

              error: (_, stack) => const SizedBox.shrink(),

            ),

            const SizedBox(height: 12),

            Text(

              'Digital health',

              style: Theme.of(context).textTheme.titleMedium?.copyWith(

                    fontWeight: FontWeight.w700,

                  ),

            ),

            const SizedBox(height: 12),

            _FeatureGrid(

              items: [

                _FeatureItem(

                  icon: Icons.health_and_safety_rounded,

                  label: 'Digital Health Card',

                  color: Colors.teal,

                  onTap: () => _open(context, const DigitalHealthCardScreen()),

                ),

                _FeatureItem(

                  icon: Icons.account_balance_wallet_rounded,

                  label: 'Certificate Wallet',

                  color: Colors.green,

                  onTap: () => _open(context, const CertificateWalletScreen()),

                ),

                _FeatureItem(

                  icon: Icons.timeline_rounded,

                  label: 'Vaccination Timeline',

                  color: Colors.indigo,

                  onTap: () => _open(context, const VaccinationTimelineScreen()),

                ),

                _FeatureItem(

                  icon: Icons.qr_code_scanner_rounded,

                  label: 'QR Verification',

                  color: Colors.deepOrange,

                  onTap: () => _open(context, const QrVerificationScreen()),

                ),

                _FeatureItem(

                  icon: Icons.confirmation_number_outlined,

                  label: 'My Ticket',

                  color: Colors.orange,

                  onTap: () => _open(context, const CampaignTicketLookupPage()),

                ),

              ],

            ),

            const SizedBox(height: 20),

            Text(

              'Campaign & reminders',

              style: Theme.of(context).textTheme.titleMedium?.copyWith(

                    fontWeight: FontWeight.w700,

                  ),

            ),

            const SizedBox(height: 12),

            _FeatureGrid(

              items: [

                _FeatureItem(

                  icon: Icons.event_note_rounded,

                  label: 'My Campaigns',

                  color: Colors.blue,

                  onTap: () => _open(context, const MyCampaignsScreen()),

                ),

                _FeatureItem(

                  icon: Icons.history_rounded,

                  label: 'Campaign History',

                  color: Colors.blueGrey,

                  onTap: () => _open(context, const CampaignHistoryScreen()),

                ),

                _FeatureItem(

                  icon: Icons.calendar_month_rounded,

                  label: 'Upcoming',

                  color: Colors.cyan,

                  onTap: () => _open(context, const UpcomingVaccinationsScreen()),

                ),

                _FeatureItem(

                  icon: Icons.notifications_active_rounded,

                  label: 'Reminders',

                  color: Colors.redAccent,

                  onTap: () => _open(context, const VaccinationRemindersScreen()),

                ),

                _FeatureItem(

                  icon: Icons.medical_services_rounded,

                  label: 'Vaccination Records',

                  color: Colors.teal.shade700,

                  onTap: () => _open(context, const VaccinationRecordsScreen()),

                ),

                _FeatureItem(

                  icon: Icons.campaign_rounded,

                  label: 'Browse Campaigns',

                  color: Colors.indigo,

                  onTap: () => _open(context, const CampaignListPage()),

                ),

                _FeatureItem(

                  icon: Icons.analytics_outlined,

                  label: 'Analytics',

                  color: Colors.deepOrange,

                  onTap: () => _open(context, const CampaignAnalyticsPage()),

                ),

                _FeatureItem(

                  icon: Icons.insights_outlined,

                  label: 'A/B Performance',

                  color: Colors.blueGrey,

                  onTap: () => _open(context, const CampaignPerformanceDashboardPage()),

                ),

                _FeatureItem(

                  icon: Icons.place_outlined,

                  label: 'Area Prefs',

                  color: Colors.green,

                  onTap: () => _open(context, const CampaignGeoPreferencesPage()),

                ),

                _FeatureItem(

                  icon: Icons.card_giftcard_rounded,

                  label: 'Campaign Benefits',

                  color: Colors.purple,

                  onTap: () => _open(context, const CampaignBenefitsScreen()),

                ),

              ],

            ),

          ],

        ),

      ),

    );

  }



  void _open(BuildContext context, Widget screen) {

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  }

}



class _ImportBanner extends StatelessWidget {

  final dynamic summary;

  final WidgetRef ref;



  const _ImportBanner({required this.summary, required this.ref});



  @override

  Widget build(BuildContext context) {

    if (!summary.hasUnlinkedRecords) {

      return Card(

        child: ListTile(

          leading: const Icon(Icons.check_circle, color: Colors.green),

          title: Text('${summary.linkedBookings} booking(s) linked'),

          subtitle: Text('${summary.vaccinations} vaccination record(s) on file'),

        ),

      );

    }



    return Card(

      color: const Color(0xFFE8F1FB),

      child: Padding(

        padding: const EdgeInsets.all(14),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Text(

              'Campaign records found',

              style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w700),

            ),

            const SizedBox(height: 6),

            Text(

              'We found ${summary.unlinkedBookings} booking(s) linked to your phone. Import them into BPA.',

            ),

            const SizedBox(height: 10),

            FilledButton(

              onPressed: () async {

                try {

                  final result =
                      await ref.read(campaignRepositoryProvider).importRecords();
                  final imported = result['imported'] ?? result['count'];
                  await ref.read(analyticsServiceProvider).logCampaignRegistered(
                        importedCount: imported is int
                            ? imported
                            : int.tryParse('$imported'),
                      );

                  ref.invalidate(campaignSummaryProvider);

                  ref.invalidate(myCampaignBookingsProvider);

                  ref.invalidate(vaccinationRecordsProvider);

                  if (context.mounted) {

                    ScaffoldMessenger.of(context).showSnackBar(

                      const SnackBar(content: Text('Campaign records imported')),

                    );

                  }

                } catch (e) {

                  if (context.mounted) {

                    ScaffoldMessenger.of(context).showSnackBar(

                      SnackBar(content: Text(e.toString())),

                    );

                  }

                }

              },

              child: const Text('Import Records'),

            ),

          ],

        ),

      ),

    );

  }

}



class _FeatureItem {

  final IconData icon;

  final String label;

  final Color color;

  final VoidCallback onTap;



  const _FeatureItem({

    required this.icon,

    required this.label,

    required this.color,

    required this.onTap,

  });

}



class _FeatureGrid extends StatelessWidget {

  final List<_FeatureItem> items;



  const _FeatureGrid({required this.items});



  @override

  Widget build(BuildContext context) {

    return GridView.builder(

      shrinkWrap: true,

      physics: const NeverScrollableScrollPhysics(),

      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(

        crossAxisCount: 2,

        mainAxisSpacing: 12,

        crossAxisSpacing: 12,

        childAspectRatio: 1.15,

      ),

      itemCount: items.length,

      itemBuilder: (context, index) {

        final item = items[index];

        return Material(

          color: Colors.white,

          borderRadius: BorderRadius.circular(14),

          elevation: 1,

          child: InkWell(

            borderRadius: BorderRadius.circular(14),

            onTap: item.onTap,

            child: Padding(

              padding: const EdgeInsets.all(14),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  CircleAvatar(

                    backgroundColor: item.color.withValues(alpha: 0.15),

                    child: Icon(item.icon, color: item.color),

                  ),

                  const Spacer(),

                  Text(

                    item.label,

                    style: const TextStyle(fontWeight: FontWeight.w600),

                  ),

                ],

              ),

            ),

          ),

        );

      },

    );

  }

}


