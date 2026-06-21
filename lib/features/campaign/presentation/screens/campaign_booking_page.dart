import 'package:bpa_app/core/analytics/analytics_events.dart';
import 'package:bpa_app/core/analytics/analytics_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/campaign_booking_draft.dart';
import '../../data/models/campaign_public_models.dart';
import '../../domain/vaccination_platform/campaign_booking_flow.dart';
import '../providers/campaign_discovery_providers.dart';
import '../providers/smart_campaign_providers.dart';
import '../utils/campaign_pricing_utils.dart';
import '../widgets/campaign_price_breakdown_card.dart';
import '../widgets/campaign_state_views.dart';
import '../widgets/city_corporation_area_picker.dart';
import 'campaign_payment_page.dart';
import 'campaign_success_page.dart';

class CampaignBookingPage extends ConsumerStatefulWidget {
  final String slug;

  const CampaignBookingPage({super.key, required this.slug});

  @override
  ConsumerState<CampaignBookingPage> createState() => _CampaignBookingPageState();
}

class _CampaignBookingPageState extends ConsumerState<CampaignBookingPage> {
  final _phoneCtrl = TextEditingController();
  final _altPhoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _phoneCtrl.text = prefs.getString('userPhone') ?? prefs.getString('phone') ?? '';
    _nameCtrl.text = prefs.getString('userName') ?? '';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  CampaignBookingDraft get _draft =>
      ref.read(campaignBookingDraftProvider(widget.slug));

  void _patchDraft(CampaignBookingDraft Function(CampaignBookingDraft) fn) {
    ref.read(campaignBookingDraftProvider(widget.slug).notifier).update(fn(_draft));
  }

  @override
  Widget build(BuildContext context) {
    final campaignAsync = ref.watch(campaignDetailProvider(widget.slug));
    final draft = ref.watch(campaignBookingDraftProvider(widget.slug));
    final padding = campaignHorizontalPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Vaccination'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (draft.step + 1) / 4,
            minHeight: 4,
          ),
        ),
      ),
      body: campaignAsync.when(
        loading: () => const CampaignLoadingView(),
        error: (e, _) => CampaignErrorView(
          message: 'Could not load campaign.',
          onRetry: () => ref.invalidate(campaignDetailProvider(widget.slug)),
        ),
        data: (campaign) => ListView(
          padding: EdgeInsets.all(padding),
          children: [
            Text(campaign.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              _stepTitle(draft.step),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ..._buildStep(context, campaign, draft),
          ],
        ),
      ),
    );
  }

  String _stepTitle(int step) {
    switch (step) {
      case 0:
        return '1. Location';
      case 1:
        return '2. Cats & pricing';
      case 2:
        return '3. Contact';
      default:
        return '4. Review & pay';
    }
  }

  List<Widget> _buildStep(BuildContext context, PublicCampaign campaign, CampaignBookingDraft draft) {
    final maxCats = campaign.config?.maxCatsPerBooking ?? campaign.maxPetsPerBooking;
    final pricing = computeCampaignPriceBreakdown(campaign: campaign, catCount: draft.catCount);

    switch (draft.step) {
      case 0:
        return [
          CityCorporationAreaPicker(
            cityCorporationCode: draft.cityCorporationCode,
            bdAreaId: draft.bdAreaId,
            onCorporationChanged: (corp) {
              _patchDraft((d) => d.copyWith(
                    cityCorporationCode: corp.code,
                    cityCorporationName: corp.displayLabel,
                    clearBdArea: true,
                    bookingArea: '',
                  ));
            },
            onAreaChanged: (area) {
              _patchDraft((d) => d.copyWith(
                    bdAreaId: area.id,
                    bookingArea: area.nameEn,
                  ));
            },
          ),
          const SizedBox(height: 24),
          _navButtons(
            showBack: false,
            onNext: draft.hasLocationSelection
                ? () => _patchDraft((d) => d.copyWith(step: 1))
                : null,
          ),
        ];
      case 1:
        return [
          Text('How many cats?', style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              IconButton(
                onPressed: draft.catCount > 1
                    ? () => _patchDraft((d) => d.copyWith(catCount: d.catCount - 1))
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('${draft.catCount}', style: Theme.of(context).textTheme.headlineSmall),
              IconButton(
                onPressed: draft.catCount < maxCats
                    ? () => _patchDraft((d) => d.copyWith(catCount: d.catCount + 1))
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          CampaignPriceBreakdownCard(pricing: pricing),
          const SizedBox(height: 24),
          _navButtons(
            onBack: () => _patchDraft((d) => d.copyWith(step: 0)),
            onNext: () => _patchDraft((d) => d.copyWith(step: 2)),
          ),
        ];
      case 2:
        return [
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Primary mobile *',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _altPhoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Alternate mobile (optional)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Your name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          _navButtons(
            onBack: () => _patchDraft((d) => d.copyWith(step: 1)),
            onNext: _phoneCtrl.text.trim().isNotEmpty
                ? () {
                    _patchDraft((d) => d.copyWith(
                          phone: _phoneCtrl.text.trim(),
                          alternatePhone: _altPhoneCtrl.text.trim(),
                          ownerName: _nameCtrl.text.trim(),
                          step: 3,
                        ));
                  }
                : null,
          ),
        ];
      default:
        return [
          _reviewTile('Corporation', draft.cityCorporationName),
          _reviewTile('Area', draft.bookingArea),
          _reviewTile('Cats', '${draft.catCount}'),
          _reviewTile('Phone', _phoneCtrl.text.trim()),
          CampaignPriceBreakdownCard(pricing: pricing),
          const SizedBox(height: 8),
          Text(
            'Campaign center and slot will be assigned automatically. You will receive SMS with booking ID and per-cat ticket links.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : () => _submit(campaign, pricing),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    campaign.isFree || pricing.total <= 0
                        ? 'Confirm booking'
                        : 'Proceed to payment — ${formatCampaignMoney(pricing.total, pricing.currency)}',
                  ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _submitting ? null : () => _patchDraft((d) => d.copyWith(step: 2)),
            child: const Text('Back'),
          ),
        ];
    }
  }

  Widget _reviewTile(String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _navButtons({
    bool showBack = true,
    VoidCallback? onBack,
    VoidCallback? onNext,
  }) {
    return Row(
      children: [
        if (showBack)
          Expanded(
            child: OutlinedButton(
              onPressed: onBack,
              child: const Text('Back'),
            ),
          ),
        if (showBack) const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: onNext,
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Future<void> _submit(PublicCampaign campaign, CampaignPriceBreakdown pricing) async {
    final phone = _phoneCtrl.text.trim();
    if (!_draft.hasLocationSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select city corporation and area')),
      );
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your mobile number')),
      );
      return;
    }

    setState(() => _submitting = true);
    ref.read(analyticsServiceProvider).logEvent(
      AnalyticsEvents.campaignBookingStarted,
      parameters: {
        'campaign_slug': widget.slug,
        'cat_count': _draft.catCount,
        'booking_mode': 'zone_interest',
      },
    );

    final draft = _draft.copyWith(
      phone: phone,
      alternatePhone: _altPhoneCtrl.text.trim(),
      ownerName: _nameCtrl.text.trim(),
      paymentMethod: campaign.isFree ? null : 'BKASH',
    );

    try {
      final result = await ref.read(campaignCheckoutProvider.notifier).submit(draft);
      if (!mounted) return;

      if (result.requiresPayment && result.paymentUrl != null) {
        ref.read(analyticsServiceProvider).logEvent(
          AnalyticsEvents.campaignPaymentStarted,
          parameters: {
            'campaign_slug': widget.slug,
            'checkout_id': result.checkoutId,
            AnalyticsEvents.amount: result.amount,
          },
        );
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CampaignPaymentPage(
              checkoutId: result.checkoutId,
              paymentUrl: result.paymentUrl!,
              slug: widget.slug,
            ),
          ),
        );
      } else {
        await _goSuccess(result.bookingRef ?? '', result.verificationCode, pricing.total);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _goSuccess(String bookingRef, String? verificationCode, num revenue) async {
    ref.read(campaignPerformanceTrackerProvider).recordBooking(
          widget.slug,
          revenue: revenue,
        );
    ref.read(analyticsServiceProvider).logEvent(
      AnalyticsEvents.campaignBookingCompleted,
      parameters: {
        'campaign_slug': widget.slug,
        'booking_ref': bookingRef,
      },
    );
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CampaignSuccessPage(
          bookingRef: bookingRef,
          verificationCode: verificationCode,
          slug: widget.slug,
        ),
      ),
    );
  }
}
