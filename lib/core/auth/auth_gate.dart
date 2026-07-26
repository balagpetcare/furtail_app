import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/legacy/presentation/screens/splash_screen.dart';
import '../navigation/app_navigator.dart';
import '../theme/theme_extensions.dart';
import 'auth_controller.dart';

/// Statuses in which the user must not be able to see or reach protected
/// content. All of them render an unauthenticated screen in [AuthGate].
bool isUnauthenticatedStatus(AuthStatus status) {
  return status == AuthStatus.unauthenticated ||
      status == AuthStatus.requiresOtp ||
      status == AuthStatus.requiresProfileCompletion ||
      status == AuthStatus.requiresAccountLinking;
}

void _authNavLog(String message) {
  if (kDebugMode) {
    debugPrint('[auth/nav] $message');
  }
}

/// Root-level auth gate: decides between splash / login / the authenticated
/// app based on [AuthController]'s bootstrap result and auth status.
///
/// This widget:
/// - Owns all top-level navigation decisions (splash → login → app)
/// - Watches [authControllerProvider] and rebuilds when auth state changes
/// - Never calls Navigator.pop() or Navigator.push() — only returns different
///   widgets based on auth status
/// - Ensures that logout (which changes auth status to unauthenticated) is
///   handled purely by returning LoginScreen, with no manual navigation
class AuthGate extends ConsumerStatefulWidget {
  final Widget authenticatedChild;

  const AuthGate({super.key, required this.authenticatedChild});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Bootstrap auth state (check tokens, fetch /auth/me, etc.) asynchronously
    // without blocking the first frame.
    Future.microtask(
      () => ref.read(authControllerProvider.notifier).bootstrap(),
    );
  }

  /// True while a post-logout route cleanup is already scheduled, so repeated
  /// auth-state emissions (duplicate taps, interceptor forceLogout racing a
  /// user-initiated logout) cannot queue redundant transitions.
  bool _clearingProtectedRoutes = false;

  /// Single authoritative owner of post-logout navigation.
  ///
  /// [AuthGate] lives in the app's *first* route, so whatever it returns from
  /// [build] already replaces the authenticated root with [LoginScreen]. The
  /// only thing left to do is discard protected routes that were pushed on top
  /// of it (settings, profile, wallet, …), otherwise the user would keep
  /// staring at a protected screen after logout and Android back would walk
  /// straight back into authenticated content.
  ///
  /// This uses `popUntil((r) => r.isFirst)`, which is safe by construction: the
  /// first route always matches, so the history can never become empty. No
  /// route is removed before a replacement exists, and nothing is pushed — the
  /// login UI is produced declaratively by this widget.
  void _clearProtectedRoutesAfterLogout() {
    if (_clearingProtectedRoutes) {
      _authNavLog('duplicate post-logout navigation ignored');
      return;
    }
    _clearingProtectedRoutes = true;
    _authNavLog('router redirect requested (clear protected routes)');

    // Defer to after the current frame: the auth state can flip mid-build, and
    // a dialog/bottom sheet may still be closing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final navigator = AppNavigator.state;
        if (navigator == null) {
          _authNavLog('root navigator unavailable; nothing to clear');
          return;
        }
        if (navigator.canPop()) {
          // Also dismisses any open dialog/bottom sheet route on the way down.
          navigator.popUntil((route) => route.isFirst);
          _authNavLog('router redirect completed (popped to first route)');
        } else {
          _authNavLog('router redirect completed (already at first route)');
        }
      } finally {
        _clearingProtectedRoutes = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      final wasUnauthenticated =
          previous != null && isUnauthenticatedStatus(previous.status);
      if (isUnauthenticatedStatus(next.status) && !wasUnauthenticated) {
        _authNavLog('auth state changed to unauthenticated');
        _clearProtectedRoutesAfterLogout();
      }
    });

    final authState = ref.watch(authControllerProvider);

    // Return different UIs based on auth status. When logout changes the status
    // to unauthenticated, this function runs again and returns LoginScreen,
    // which naturally replaces the authenticated app without any manual
    // Navigator operations.
    return switch (authState.status) {
      // Initial state while bootstrap is in flight or before bootstrap starts.
      AuthStatus.unknown => const SplashScreen(),

      // Bootstrap failed and user can retry or force logout.
      AuthStatus.bootstrapFailed => BootstrapRetryScreen(
        message: authState.lastError,
        onRetry: () => ref.read(authControllerProvider.notifier).bootstrap(),
        onLogout: () => ref.read(authControllerProvider.notifier).logout(),
      ),

      // User is logged out. Show login UI. This is also the state after a
      // successful logout (which calls resetSessionScopedState → logout).
      AuthStatus.unauthenticated => const LoginScreen(),

      // User is authenticated. Show the full app.
      AuthStatus.authenticated => widget.authenticatedChild,

      // OTP verification pending. No dedicated screen yet; fall back to login.
      AuthStatus.requiresOtp => const LoginScreen(),

      // Profile completion required. No dedicated screen yet; fall back to login.
      AuthStatus.requiresProfileCompletion => const LoginScreen(),

      // Account linking required. No dedicated screen yet; fall back to login.
      AuthStatus.requiresAccountLinking => const LoginScreen(),

      // Definitive, non-retryable error. Show retry/logout options.
      AuthStatus.error => BootstrapRetryScreen(
        message: authState.lastError,
        onRetry: () => ref.read(authControllerProvider.notifier).bootstrap(),
        onLogout: () => ref.read(authControllerProvider.notifier).logout(),
      ),
    };
  }
}

class BootstrapRetryScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onLogout;
  final String? message;

  const BootstrapRetryScreen({
    super.key,
    required this.onRetry,
    required this.onLogout,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 48, color: primary),
                const SizedBox(height: 16),
                Text(
                  message ??
                      'Something went wrong. Please check your connection and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(backgroundColor: primary),
                  child: const Text('Retry'),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: onLogout, child: const Text('Log out')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
