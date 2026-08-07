import 'package:flutter/widgets.dart';

import '../../data/models/user_profile_model.dart';
import 'profile_settings_hub_screen.dart';

/// Legacy route kept as a pass-through so older navigation paths still land
/// on the canonical profile editor.
class ProfileEditOverviewScreen extends StatelessWidget {
  const ProfileEditOverviewScreen({super.key, required this.initial});

  final UserProfileModel initial;

  @override
  Widget build(BuildContext context) {
    return EditProfileScreen(initial: initial);
  }
}
