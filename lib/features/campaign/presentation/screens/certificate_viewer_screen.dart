import 'dart:convert';

import 'package:furtail_app/core/analytics/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/campaign_providers.dart';
import 'qr_viewer_screen.dart';

class CertificateViewerScreen extends ConsumerStatefulWidget {
  final String token;

  const CertificateViewerScreen({super.key, required this.token});

  @override
  ConsumerState<CertificateViewerScreen> createState() =>
      _CertificateViewerScreenState();
}

class _CertificateViewerScreenState extends ConsumerState<CertificateViewerScreen> {
  bool _downloading = false;
  bool _certificateViewLogged = false;

  @override
  Widget build(BuildContext context) {
    final certAsync = ref.watch(certificateProvider(widget.token));

    certAsync.whenData((_) {
      if (!_certificateViewLogged) {
        _certificateViewLogged = true;
        AnalyticsService.instance.logCertificateViewed(
          hasToken: widget.token.isNotEmpty,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificate'),
        actions: certAsync.maybeWhen(
          data: (cert) => [
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share link',
              onPressed: () =>
                  ref.read(certificateShareServiceProvider).shareCertificateLink(cert),
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Share PDF',
              onPressed: _downloading ? null : () => _download(context),
            ),
          ],
          orElse: () => [
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: _downloading ? null : () => _download(context),
            ),
          ],
        ),
      ),
      body: certAsync.when(
        data: (cert) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cert.petName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(cert.campaignName),
                      const Divider(height: 24),
                      _info('Token', cert.certificateToken),
                      _info('Owner', cert.ownerName),
                      _info('Animal', cert.animalType),
                      if (cert.breed != null) _info('Breed', cert.breed!),
                      _info('Vaccine', cert.vaccineType),
                      _info(
                        'Vaccinated',
                        cert.vaccinatedAt != null
                            ? DateFormat('d MMM yyyy').format(cert.vaccinatedAt!)
                            : '—',
                      ),
                      _info(
                        'Valid until',
                        cert.validUntil != null
                            ? DateFormat('d MMM yyyy').format(cert.validUntil!)
                            : '—',
                      ),
                      _info('Location', cert.location),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (cert.qrCodeImage.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QrViewerScreen(
                          title: cert.certificateToken,
                          payload: cert.certificateToken,
                          subtitle: cert.petName,
                          qrImageBase64: cert.qrCodeImage,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('View QR Code'),
                ),
              if (cert.qrCodeImage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Center(child: _qrImage(cert.qrCodeImage)),
              ],
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _qrImage(String base64Data) {
    try {
      final raw = base64Data.contains(',')
          ? base64Data.split(',').last
          : base64Data;
      final bytes = base64Decode(raw);
      return Image.memory(bytes, height: 180, fit: BoxFit.contain);
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Future<void> _download(BuildContext context) async {
    setState(() => _downloading = true);
    try {
      final ok = await ref
          .read(certificateShareServiceProvider)
          .shareCertificatePdf(widget.token);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF download unavailable on server')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }
}
