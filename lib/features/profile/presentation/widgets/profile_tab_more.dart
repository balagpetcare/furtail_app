import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// More tab for own profile — clean settings-style rows.
///
/// Pass callbacks for implemented actions from the parent screen.
/// Items marked [comingSoon] show a "Soon" badge and are non-tappable.
class ProfileTabMore extends StatelessWidget {
  final VoidCallback? onEditProfile;
  final VoidCallback? onSavedPosts;
  final VoidCallback? onShareProfile;
  final VoidCallback? onAddPet;
  final VoidCallback? onMyPets;
  final String? profileLink;

  const ProfileTabMore({
    super.key,
    this.onEditProfile,
    this.onSavedPosts,
    this.onShareProfile,
    this.onAddPet,
    this.onMyPets,
    this.profileLink,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _label('Profile'),
        _row(context, cs, Icons.edit_outlined,         'Edit Profile',       onEditProfile),
        _row(context, cs, Icons.lock_outline_rounded,  'Profile Privacy',    null, comingSoon: true),
        _row(context, cs, Icons.bookmark_border_rounded, 'Saved Posts',      onSavedPosts),
        _row(context, cs, Icons.share_rounded,         'Share Profile',      onShareProfile),
        if (profileLink != null)
          _row(context, cs, Icons.link_rounded, 'Copy Profile Link', () {
            Clipboard.setData(ClipboardData(text: profileLink!));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile link copied'),
                duration: Duration(seconds: 2),
              ),
            );
          }),
        const SizedBox(height: 16),
        _label('Pets'),
        _row(context, cs, Icons.pets_rounded,               'My Pets', onMyPets),
        _row(context, cs, Icons.add_circle_outline_rounded, 'Add Pet', onAddPet),
        const SizedBox(height: 16),
        _label('Account'),
        _row(context, cs, Icons.emoji_events_outlined, 'My Awards',        null, comingSoon: true),
        _row(context, cs, Icons.history_rounded,        'Activity History', null, comingSoon: true),
        _row(context, cs, Icons.block_rounded,          'Blocked Users',    null, comingSoon: true),
        _row(context, cs, Icons.flag_outlined,          'Report a Problem', null, comingSoon: true),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
      ],
    );
  }

  static Widget _label(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    ColorScheme cs,
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool comingSoon = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 0,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: cs.primary),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      trailing: comingSoon
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Soon',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
      enabled: !comingSoon,
      onTap: comingSoon ? null : onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
