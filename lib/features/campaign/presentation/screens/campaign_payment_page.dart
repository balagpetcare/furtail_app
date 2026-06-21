import 'package:furtail_app/core/analytics/analytics_events.dart';
import 'package:furtail_app/core/analytics/analytics_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../providers/campaign_discovery_providers.dart';
import '../providers/smart_campaign_providers.dart';
import '../widgets/campaign_state_views.dart';
import 'campaign_success_page.dart';

class CampaignPaymentPage extends ConsumerStatefulWidget {
  final String checkoutId;
  final String paymentUrl;
  final String slug;

  const CampaignPaymentPage({
    super.key,
    required this.checkoutId,
    required this.paymentUrl,
    required this.slug,
  });

  @override
  ConsumerState<CampaignPaymentPage> createState() => _CampaignPaymentPageState();
}

class _CampaignPaymentPageState extends ConsumerState<CampaignPaymentPage> {
  late final WebViewController _controller;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (change) {
            final url = change.url ?? '';
            if (url.contains('campaign/checkout/success') ||
                url.startsWith('furtail://campaign/checkout/success')) {
              _onSuccess();
            } else if (url.contains('campaign/checkout/failed') ||
                url.startsWith('furtail://campaign/checkout/failed')) {
              _onFailed();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  Future<void> _onSuccess() async {
    if (_polling) return;
    _polling = true;
    try {
      final status = await ref
          .read(campaignCheckoutProvider.notifier)
          .pollStatus(widget.checkoutId);
      if (!mounted) return;
      if (status.isPaid) {
        ref.read(analyticsServiceProvider).logEvent(
          AnalyticsEvents.campaignPaymentCompleted,
          parameters: {
            'campaign_slug': widget.slug,
            'checkout_id': widget.checkoutId,
          },
        );
        ref.read(campaignPerformanceTrackerProvider).recordPayment(
              widget.slug,
              amount: status.amount,
            );
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CampaignSuccessPage(
              bookingRef: status.bookingRef ?? '',
              verificationCode: status.verificationCode,
              slug: widget.slug,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment status check failed. Tap refresh.')),
        );
      }
    } finally {
      _polling = false;
    }
  }

  void _onFailed() {
    ref.read(analyticsServiceProvider).logEvent(
      AnalyticsEvents.campaignPaymentFailed,
      parameters: {'campaign_slug': widget.slug, 'checkout_id': widget.checkoutId},
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment was not completed.')),
    );
  }

  Future<void> _manualCheck() async {
    setState(() => _polling = true);
    try {
      final status = await ref
          .read(campaignCheckoutProvider.notifier)
          .pollStatus(widget.checkoutId);
      if (!mounted) return;
      if (status.isPaid) {
        await _onSuccess();
      } else if (status.isFailed) {
        _onFailed();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status: ${status.status}')),
        );
      }
    } finally {
      if (mounted) setState(() => _polling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        actions: [
          TextButton(
            onPressed: _polling ? null : _manualCheck,
            child: const Text('I paid'),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_polling)
            const ColoredBox(
              color: Color(0x44FFFFFF),
              child: CampaignLoadingView(message: 'Confirming payment…'),
            ),
        ],
      ),
    );
  }
}
