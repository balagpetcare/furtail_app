import 'package:furtail_app/core/analytics/analytics_service.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'dart:convert';

import 'package:flutter/material.dart';

class QrViewerScreen extends StatefulWidget {
  final String title;
  final String payload;
  final String? subtitle;
  final String? qrImageBase64;

  const QrViewerScreen({
    super.key,
    required this.title,
    required this.payload,
    this.subtitle,
    this.qrImageBase64,
  });

  @override
  State<QrViewerScreen> createState() => _QrViewerScreenState();
}

class _QrViewerScreenState extends State<QrViewerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.instance.logQrViewed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Code')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 6),
                Text(widget.subtitle!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              if (widget.qrImageBase64 != null && widget.qrImageBase64!.isNotEmpty)
                _buildImage(widget.qrImageBase64!)
              else
                _buildPlaceholder(context),
              const SizedBox(height: 20),
              SelectableText(
                widget.payload,
                style: const TextStyle(fontFamily: 'monospace'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Show this QR at the vaccination site for check-in or verification.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String base64Data) {
    try {
      final raw = base64Data.contains(',') ? base64Data.split(',').last : base64Data;
      final bytes = base64Decode(raw);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
        ),
        child: Image.memory(bytes, width: 220, height: 220, fit: BoxFit.contain),
      );
    } catch (_) {
      return _buildPlaceholder(null);
    }
  }

  Widget _buildPlaceholder(BuildContext? context) {
    return Container(
      width: 220,
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_rounded, size: 120, color: Colors.grey.shade700),
          if (context != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'QR image not available',
                style: context!.appText.bodySmall!.copyWith(color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }
}
