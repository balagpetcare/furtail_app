import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/campaign_providers.dart';
import 'certificate_viewer_screen.dart';
import 'qr_viewer_screen.dart';

/// Public certificate verification by token (QR payload).
class QrVerificationScreen extends ConsumerStatefulWidget {
  final String? initialToken;

  const QrVerificationScreen({super.key, this.initialToken});

  @override
  ConsumerState<QrVerificationScreen> createState() => _QrVerificationScreenState();
}

class _QrVerificationScreenState extends ConsumerState<QrVerificationScreen> {
  late final TextEditingController _controller;
  Map<String, dynamic>? _result;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialToken ?? '');
    if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final token = _controller.text.trim().toUpperCase();
    if (token.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final data = await ref.read(campaignRepositoryProvider).verifyCertificatePublic(token);
      if (mounted) {
        setState(() => _result = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Verification'),
        backgroundColor: context.colorScheme.primary,
        foregroundColor: context.colorScheme.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Enter the certificate token from a QR code or SMS to verify authenticity.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Certificate token',
              hintText: 'e.g. Furtail-XXXXXXXX',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste_rounded),
                onPressed: () async {
                  final clip = await Clipboard.getData(Clipboard.kTextPlain);
                  if (clip?.text != null) {
                    _controller.text = clip!.text!.trim();
                  }
                },
              ),
            ),
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _verify,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.verified_user_rounded),
            label: const Text('Verify certificate'),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
              ),
            ),
          if (_result != null) _VerificationResultCard(
            data: _result!,
            token: _controller.text.trim().toUpperCase(),
            onViewFull: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CertificateViewerScreen(token: _controller.text.trim().toUpperCase()),
                ),
              );
            },
            onShowQr: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QrViewerScreen(
                    title: 'Verify QR',
                    payload: _controller.text.trim().toUpperCase(),
                    subtitle: _result!['petName']?.toString(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VerificationResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String token;
  final VoidCallback onViewFull;
  final VoidCallback onShowQr;

  const _VerificationResultCard({
    required this.data,
    required this.token,
    required this.onViewFull,
    required this.onShowQr,
  });

  @override
  Widget build(BuildContext context) {
    final valid = data['valid'] == true || data['status']?.toString().toUpperCase() == 'VALID';
    final petName = data['petName']?.toString() ?? data['pet']?['name']?.toString() ?? '—';
    final vaccine = data['vaccineType']?.toString() ?? data['vaccine']?.toString() ?? '—';
    final vaccinatedAt = _parseDate(data['vaccinatedAt'] ?? data['administeredAt']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  valid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: valid ? Colors.green : Colors.red,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    valid ? 'Certificate is valid' : 'Certificate not found or invalid',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (valid) ...[
              const Divider(height: 24),
              _line('Pet', petName),
              _line('Vaccine', vaccine),
              if (vaccinatedAt != null)
                _line('Vaccinated', DateFormat('d MMM yyyy').format(vaccinatedAt)),
              _line('Token', token),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: onShowQr, icon: const Icon(Icons.qr_code_2), label: const Text('Show QR')),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onViewFull,
                icon: const Icon(Icons.description_outlined),
                label: const Text('Open full certificate'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
