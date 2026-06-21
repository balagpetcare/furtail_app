import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/campaign_providers.dart';
import 'qr_viewer_screen.dart';

/// Vaccination-day ticket lookup by token or booking ID (manual entry).
class CampaignTicketLookupPage extends ConsumerStatefulWidget {
  const CampaignTicketLookupPage({super.key});

  @override
  ConsumerState<CampaignTicketLookupPage> createState() => _CampaignTicketLookupPageState();
}

class _CampaignTicketLookupPageState extends ConsumerState<CampaignTicketLookupPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(campaignRepositoryProvider);
      final refUpper = query.toUpperCase();
      final tickets = refUpper.startsWith('VAC-')
          ? await repo.fetchBookingTickets(refUpper)
          : await repo.fetchBookingTickets(query);

      if (!mounted) return;
      if (tickets.isEmpty) {
        setState(() => _error = 'No tickets found for this reference.');
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QrViewerScreen(
            title: tickets.first.petName,
            payload: tickets.first.ticketToken,
            subtitle: tickets.first.bookingRef,
            qrImageBase64: tickets.first.qrImageBase64?.contains(',') == true
                ? tickets.first.qrImageBase64!.split(',').last
                : tickets.first.qrImageBase64,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket lookup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter your booking ID (VAC-…) or ticket token from SMS to view your vaccination ticket.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Booking ID or ticket token',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _lookup,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Find ticket'),
            ),
          ],
        ),
      ),
    );
  }
}
