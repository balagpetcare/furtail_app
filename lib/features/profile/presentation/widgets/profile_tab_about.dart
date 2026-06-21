import 'package:flutter/material.dart';
import '../../data/models/user_profile_model.dart';

class ProfileTabAbout extends StatelessWidget {
  final UserProfileModel profile;
  final VoidCallback? onSeeMore;

  const ProfileTabAbout({
    super.key,
    required this.profile,
    this.onSeeMore,
  });

  @override
  Widget build(BuildContext context) {
    Widget row(String k, String? v) {
      final value = (v ?? '').trim().isEmpty ? 'Not set' : v!.trim();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(value, textAlign: TextAlign.right),
            ),
          ],
        ),
      );
    }

    String fmtDate(DateTime? d) {
      if (d == null) return 'Not set';
      return "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          row('Education', profile.education),
          row('Place live', profile.placeLive),
          row('Fans and friends', profile.fansAndFriends),
          row('From', profile.from),
          row('Profile type', profile.profileType),
          row('Work status', profile.workStatus),
          row('Religious status', profile.religiousStatus),
          row('Gender', profile.gender),
          row('Birthdate', fmtDate(profile.birthdate)),
          row('Marital status', profile.maritalStatus),
          const SizedBox(height: 12),
          if (onSeeMore != null)
            OutlinedButton(
              onPressed: onSeeMore,
              child: const Text('See more / Edit'),
            ),
        ],
      ),
    );
  }
}
