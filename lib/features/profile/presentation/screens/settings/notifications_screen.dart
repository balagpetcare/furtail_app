import 'package:flutter/material.dart';

import '../../../data/profile_service.dart';
import '../../widgets/section_error_state.dart';
import '../../widgets/settings_scaffold.dart';

const _kToggleKeys = [
  ('likes', 'Likes', 'Someone likes your post or comment'),
  ('comments', 'Comments', 'Someone comments on your post'),
  ('follows', 'Follows', 'Someone follows you'),
  ('mentions', 'Mentions', 'Someone mentions you'),
  ('messages', 'Messages', 'You receive a new message'),
  ('fundraisingUpdates', 'Fundraising updates', 'Updates on campaigns you follow or donated to'),
  ('adoptionUpdates', 'Adoption updates', 'Updates on adoption listings you follow'),
  ('emailAnnouncements', 'Email announcements', 'Occasional product news by email'),
  ('smsAnnouncements', 'SMS announcements', 'Occasional product news by SMS'),
];

/// Real, persisted notification preferences.
/// Backend: GET/PATCH /api/v1/user/me/notification-preferences
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.profileService});
  final ProfileService? profileService;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final ProfileService _svc = widget.profileService ?? ProfileService();
  Map<String, dynamic>? _prefs;
  Object? _error;
  bool _loading = true;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await _svc.getNotificationPreferences();
      if (!mounted) return;
      setState(() => _prefs = prefs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String key, bool value) async {
    final previous = _prefs?[key];
    setState(() {
      _prefs = {...?_prefs, key: value};
      _saving.add(key);
    });
    try {
      final updated = await _svc.updateNotificationPreferences({key: value});
      if (!mounted) return;
      setState(() => _prefs = updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs = {...?_prefs, key: previous});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Notifications',
      scrollable: false,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: SectionErrorState(
                error: _error!,
                onRetry: _load,
                title: 'Notification settings could not be loaded',
              ),
            )
          : ListView(
              children: [
                for (final (key, title, subtitle) in _kToggleKeys)
                  SwitchListTile(
                    title: Text(title),
                    subtitle: Text(subtitle),
                    value: (_prefs?[key] as bool?) ?? false,
                    onChanged: _saving.contains(key) ? null : (v) => _toggle(key, v),
                    secondary: _saving.contains(key)
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
              ],
            ),
    );
  }
}
