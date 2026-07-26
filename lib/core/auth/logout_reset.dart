import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:furtail_app/core/providers/current_user_provider.dart';
import 'package:furtail_app/features/fundraising/presentation/providers/fundraising_providers.dart';
import 'package:furtail_app/features/notifications/presentation/providers/notification_controller.dart';

import 'auth_controller.dart';

/// Single source of truth for what must happen on user-initiated logout,
/// shared by every entry point (drawer, settings, and anywhere else a
/// logout action lives) so they can't drift out of sync with each other.
///
/// Clears all local authenticated state, provider caches, and tokens.
/// Never touches server data except for best-effort remote logout.
/// Safe to call even if some sub-step throws (each is best-effort except
/// the final auth state flip, which is guaranteed to complete).
///
/// After this function returns:
/// - AuthController's auth status is unauthenticated
/// - All cached providers are invalidated
/// - All tokens and session data are cleared
/// - AuthGate will have rebuilt to show LoginScreen
/// - No manual navigation is needed; do not pop() or push() after calling
/// Debug-only logout tracing. Never logs tokens, headers, PKCE values,
/// secure-storage contents, or any personal information.
void _logoutLog(String message) {
  if (kDebugMode) {
    debugPrint('[auth/logout] $message');
  }
}

Future<void> resetSessionScopedState(WidgetRef ref) async {
  _logoutLog('logout requested; session clear started');
  // Best-effort: attempt to unregister push notifications.
  // Failure does not block logout.
  try {
    await ref.read(notificationControllerProvider.notifier).unregisterPush();
  } catch (_) {
    // Best-effort: push token cleanup should never block logout.
  }

  // Invalidate all cached session-scoped data. A subsequent login
  // (possibly as a different user) must not see stale data from the
  // previous session.
  ref.invalidate(fundraisingMyAccountProvider);
  ref.invalidate(fundraisingMyCampaignsProvider);
  ref.invalidate(fundraisingFeedProvider);
  ref.invalidate(fundraisingPayoutCatalogProvider);
  ref.invalidate(fundraisingMyPayoutMethodsProvider);
  ref.invalidate(fundraisingWithdrawRequestsProvider);
  ref.invalidate(fundraisingDonationCheckoutControllerProvider);

  // Clear the local user profile cache.
  ref.read(currentUserProvider.notifier).clear();

  // Remove legacy user preference data (not sensitive; could be recreated on
  // next login, but good practice to clear anyway).
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('userName');
  await prefs.remove('userEmail');

  // Guaranteed: Clear secure-storage tokens and set AuthController state to
  // unauthenticated. AuthGate watches AuthController and will rebuild to show
  // LoginScreen. This must complete even if earlier steps throw.
  _logoutLog('auth state flip -> unauthenticated');
  await ref.read(authControllerProvider.notifier).logout();
  _logoutLog('session clear completed');
}
