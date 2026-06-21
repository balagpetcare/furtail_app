import 'package:bpa_app/core/analytics/analytics_events.dart';
import 'package:bpa_app/core/analytics/analytics_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/campaign_public_models.dart';
import '../../widgets/campaign_price_badge.dart';
import '../providers/campaign_discovery_providers.dart';
import '../widgets/campaign_state_views.dart';
import 'campaign_booking_page.dart';

class CampaignDetailsPage extends ConsumerWidget {
  final String slug;

  const CampaignDetailsPage({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(campaignDetailProvider(slug));
    final padding = campaignHorizontalPadding(context);
    final maxWidth = campaignIsTablet(context) ? 720.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(title: const Text('Campaign Details')),
      body: async.when(
        loading: () => const CampaignLoadingView(),
        error: (e, _) => CampaignErrorView(
          message: 'Campaign not found or unavailable.',
          onRetry: () => ref.invalidate(campaignDetailProvider(slug)),
        ),
        data: (campaign) => _DetailsBody(
          campaign: campaign,
          padding: padding,
          maxWidth: maxWidth,
          onBook: () {
            ref.read(analyticsServiceProvider).logEvent(
              AnalyticsEvents.campaignBookingStarted,
              parameters: {'campaign_slug': slug},
            );
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CampaignBookingPage(slug: slug)),
            );
          },
        ),
      ),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  final PublicCampaign campaign;
  final double padding;
  final double maxWidth;
  final VoidCallback onBook;

  const _DetailsBody({
    required this.campaign,
    required this.padding,
    required this.maxWidth,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _image(campaign),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      campaign.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    CampaignPriceBadge(campaign: campaign),
                    const SizedBox(height: 12),
                    Text(
                      '${dateFmt.format(campaign.startDate)} – ${dateFmt.format(campaign.endDate)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (campaign.description != null) ...[
                      const SizedBox(height: 16),
                      Text(campaign.description!),
                    ],
                    if (campaign.packageFeatures.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Package includes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...campaign.packageFeatures.map(
                        (f) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.check_circle_outline, size: 20),
                          title: Text(f),
                        ),
                      ),
                    ],
                    if (campaign.locations.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Locations',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ...campaign.locations.map(
                        (l) => ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(l.name),
                          subtitle: l.address != null ? Text(l.address!) : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: FilledButton(
                  onPressed: campaign.config?.bookingEnabled == false ? null : onBook,
                  child: const Text('Book Now'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _image(PublicCampaign campaign) {
    const fallback = 'assets/images/doctor.png';
    final url = campaign.imageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Image.asset(fallback, fit: BoxFit.cover),
      );
    }
    return Image.asset(fallback, fit: BoxFit.cover);
  }
}
