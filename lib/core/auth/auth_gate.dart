import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/legacy/presentation/screens/splash_screen.dart';
import '../theme/theme_extensions.dart';
import 'auth_controller.dart';

/// Root-level auth gate: decides between splash / login / the authenticated
/// app based on [AuthController]'s bootstrap result. Owns all navigation
/// decisions that [SplashScreen] used to make on its own.
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
    Future.microtask(
      () => ref.read(authControllerProvider.notifier).bootstrap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    return switch (authState.status) {
      AuthStatus.unknown => const SplashScreen(),
      AuthStatus.bootstrapFailed => BootstrapRetryScreen(
        message: authState.lastError,
        onRetry: () => ref.read(authControllerProvider.notifier).bootstrap(),
        onLogout: () => ref.read(authControllerProvider.notifier).logout(),
      ),
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.authenticated => widget.authenticatedChild,
      // These three states are reachable in the data layer (OTP challenge,
      // profile completion, account linking) but no dedicated screens exist
      // yet — building them is explicitly out of scope for this pass. Fall
      // back to the login screen rather than leaving a blank route; wire a
      // real screen per state when that UI work is scheduled.
      AuthStatus.requiresOtp => const LoginScreen(),
      AuthStatus.requiresProfileCompletion => const LoginScreen(),
      AuthStatus.requiresAccountLinking => const LoginScreen(),
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
