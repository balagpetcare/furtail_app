import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/profile_service.dart';
import 'settings/public_profile_screen.dart';
import 'settings/profile_appearance_screen.dart';
import 'settings/personal_details_screen.dart';
import 'settings/work_education_screen.dart';
import 'settings/places_links_screen.dart';
import 'settings/privacy_visibility_screen.dart';
import 'settings/social_interactions_screen.dart';
import 'settings/safety_screen.dart';
import 'settings/notifications_screen.dart';
import 'settings/account_security_screen.dart';
import 'settings/data_account_screen.dart';

/// Hub for the 11 Profile Settings sections. Each item opens a focused
/// child screen that owns its own save flow — the hub itself never saves
/// anything and has no global Save action.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.initial, this.profileService});
  final UserProfileModel initial;
  final ProfileService? profileService;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    final svc = widget.profileService;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings Hub')),
      body: ListView(
        children: [
          _hubTile(
            icon: Icons.image_outlined,
            title: 'Profile Appearance',
            onTap: () => _open(ProfileAppearanceScreen(initial: initial, profileService: svc)),
          ),
          _hubTile(
            icon: Icons.person_outline,
            title: 'Public Profile',
            onTap: () => _open(PublicProfileScreen(initial: initial, profileService: svc)),
          ),
          _hubTile(
            icon: Icons.badge_outlined,
            title: 'Personal Details',
            onTap: () => _open(PersonalDetailsScreen(profileService: svc)),
          ),
          _hubTile(
            icon: Icons.work_outline,
            title: 'Work and Education',
            onTap: () => _open(WorkEducationScreen(initial: initial, profileService: svc)),
          ),
          _hubTile(
            icon: Icons.place_outlined,
            title: 'Places and Links',
            onTap: () => _open(PlacesLinksScreen(initial: initial, profileService: svc)),
          ),
          _hubTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy and Visibility',
            onTap: () => _open(PrivacyVisibilityScreen(initial: initial, profileService: svc)),
          ),
          _hubTile(
            icon: Icons.people_outline,
            title: 'Social Interactions',
            onTap: () => _open(SocialInteractionsScreen(initial: initial, profileService: svc)),
          ),
          _hubTile(
            icon: Icons.shield_outlined,
            title: 'Safety',
            onTap: () => _open(const SafetyScreen()),
          ),
          _hubTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: () => _open(NotificationsScreen(profileService: svc)),
          ),
          _hubTile(
            icon: Icons.lock_outline,
            title: 'Account and Security',
            onTap: () => _open(AccountSecurityScreen(profileService: svc)),
          ),
          _hubTile(
            icon: Icons.storage_outlined,
            title: 'Data and Account',
            onTap: () => _open(DataAccountScreen(profileService: svc)),
          ),
        ],
      ),
    );
  }

  Widget _hubTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
