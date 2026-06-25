import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Immutable snapshot of the currently logged-in user's display fields.
/// Auth tokens are NOT stored here — they remain in [LocalStorage].
class CurrentUser {
  final String name;
  final String email;
  final int? userId;
  final String? avatarUrl;

  const CurrentUser({
    this.name = 'Guest',
    this.email = '',
    this.userId,
    this.avatarUrl,
  });

  static const guest = CurrentUser();
}

/// Reactive holder for the current user's display state.
///
/// Initialized from SharedPreferences on construction so every Widget that
/// watches [currentUserProvider] immediately gets the last-known user info.
class CurrentUserNotifier extends StateNotifier<CurrentUser> {
  CurrentUserNotifier() : super(CurrentUser.guest) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = CurrentUser(
      name: prefs.getString('userName') ?? 'Guest',
      email: prefs.getString('userEmail') ?? '',
      userId: prefs.getInt('userId'),
      avatarUrl: prefs.getString('avatarUrl'),
    );
  }

  /// Update the avatar URL immediately (persists to SharedPreferences).
  /// Pass `null` or an empty string to clear the avatar.
  Future<void> updateAvatar(String? url) async {
    final trimmed = (url ?? '').trim().isEmpty ? null : url!.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed != null) {
      await prefs.setString('avatarUrl', trimmed);
    } else {
      await prefs.remove('avatarUrl');
    }
    state = CurrentUser(
      name: state.name,
      email: state.email,
      userId: state.userId,
      avatarUrl: trimmed,
    );
  }

  /// Reload all fields from SharedPreferences.
  /// Call this after any operation that writes to prefs directly
  /// (e.g. EditProfileScreen.save()).
  Future<void> reloadFromPrefs() async => _loadFromPrefs();

  /// Clear all user state on logout.
  void clear() => state = CurrentUser.guest;
}

final currentUserProvider =
    StateNotifierProvider<CurrentUserNotifier, CurrentUser>(
  (ref) => CurrentUserNotifier(),
);
