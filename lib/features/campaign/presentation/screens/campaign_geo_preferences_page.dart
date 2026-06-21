import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/smart_campaign/campaign_geo_target.dart';
import '../providers/campaign_discovery_providers.dart';
import '../providers/smart_campaign_providers.dart';
import '../widgets/campaign_state_views.dart';

/// User geo preferences for geo-targeted campaign notifications.
class CampaignGeoPreferencesPage extends ConsumerStatefulWidget {
  const CampaignGeoPreferencesPage({super.key});

  @override
  ConsumerState<CampaignGeoPreferencesPage> createState() => _CampaignGeoPreferencesPageState();
}

class _CampaignGeoPreferencesPageState extends ConsumerState<CampaignGeoPreferencesPage> {
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await ref.read(userGeoPreferencesServiceProvider).load();
    _cityCtrl.text = prefs.city ?? '';
    _districtCtrl.text = prefs.district ?? '';
    _areaCtrl.text = prefs.serviceArea ?? '';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final prefs = UserGeoPreferences(
      city: _cityCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      serviceArea: _areaCtrl.text.trim(),
    );
    await ref.read(userGeoPreferencesServiceProvider).save(prefs);
    ref.invalidate(userGeoPreferencesProvider);
    ref.invalidate(homeCampaignsProvider);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location preferences saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campaign area preferences')),
      body: ListView(
        padding: EdgeInsets.all(campaignHorizontalPadding(context)),
        children: [
          const Text(
            'You will only receive campaign notifications when a drive matches your city, district, or preferred service area.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cityCtrl,
            decoration: const InputDecoration(labelText: 'City'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _districtCtrl,
            decoration: const InputDecoration(labelText: 'District'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _areaCtrl,
            decoration: const InputDecoration(labelText: 'Preferred service area'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save preferences'),
          ),
        ],
      ),
    );
  }
}
