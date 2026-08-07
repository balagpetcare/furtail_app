import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/session_recovery.dart';
import 'package:furtail_app/features/profile/data/profile_service.dart';
import 'package:furtail_app/features/profile/presentation/screens/settings/account_security_screen.dart';
import 'package:furtail_app/features/profile/presentation/screens/settings/personal_details_screen.dart';

/// Fails a call after [failTimes] attempts have already failed, then
/// succeeds — models "Retry re-invokes the same recovery-wrapped call, and
/// a transient session hiccup resolves itself."
class _FlakyProfileService extends ProfileService {
  _FlakyProfileService({this.identityFailTimes = 0, this.sessionsFailTimes = 0});

  final int identityFailTimes;
  final int sessionsFailTimes;
  int identityCallCount = 0;
  int sessionsCallCount = 0;

  @override
  Future<CentralAuthUser> getAccountIdentity() async {
    identityCallCount++;
    if (identityCallCount <= identityFailTimes) {
      // The exact shape SessionRecovery.run() throws after a definitive
      // refresh failure — never the raw backend "Invalid or expired access
      // token." string.
      throw const SessionRecoveryException('Your session has expired. Please sign in again.');
    }
    return CentralAuthUser(id: 'u1', displayName: 'Test User', firstName: 'Test', lastName: 'User');
  }

  @override
  Future<List<CentralAuthSession>> listSessions() async {
    sessionsCallCount++;
    if (sessionsCallCount <= sessionsFailTimes) {
      throw const SessionRecoveryException('Your session has expired. Please sign in again.');
    }
    return const [];
  }
}

/// Always fails with the same [SessionRecoveryException] — models a
/// genuinely expired session that Retry cannot fix without a real
/// refresh/login.
class _AlwaysExpiredProfileService extends ProfileService {
  int identityCallCount = 0;
  int sessionsCallCount = 0;

  @override
  Future<CentralAuthUser> getAccountIdentity() async {
    identityCallCount++;
    throw const SessionRecoveryException('Your session has expired. Please sign in again.');
  }

  @override
  Future<List<CentralAuthSession>> listSessions() async {
    sessionsCallCount++;
    throw const SessionRecoveryException('Your session has expired. Please sign in again.');
  }
}

const _rawTokenMessage = 'Invalid or expired access token.';

void main() {
  group('Personal Details — session recovery', () {
    testWidgets('never shows the raw backend token message', (tester) async {
      final svc = _AlwaysExpiredProfileService();
      await tester.pumpWidget(MaterialApp(home: PersonalDetailsScreen(profileService: svc)));
      await tester.pumpAndSettle();

      expect(find.textContaining(_rawTokenMessage), findsNothing);
      expect(find.textContaining('Your session has expired'), findsOneWidget);
    });

    testWidgets('Retry re-invokes the recovery-wrapped load, not a dead button', (tester) async {
      final svc = _FlakyProfileService(identityFailTimes: 1);
      await tester.pumpWidget(MaterialApp(home: PersonalDetailsScreen(profileService: svc)));
      await tester.pumpAndSettle();

      expect(svc.identityCallCount, 1);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Retry called getAccountIdentity() again (the same recovery-wrapped
      // path), and this time it succeeded.
      expect(svc.identityCallCount, 2);
      expect(find.text('Retry'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'First name'), findsOneWidget);
    });
  });

  group('Account and Security — session recovery', () {
    testWidgets('never shows the raw backend token message', (tester) async {
      final svc = _AlwaysExpiredProfileService();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: AccountSecurityScreen(profileService: svc)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(_rawTokenMessage), findsNothing);
    });

    testWidgets('shows exactly one error banner for one shared session failure, not two', (
      tester,
    ) async {
      final svc = _AlwaysExpiredProfileService();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: AccountSecurityScreen(profileService: svc)),
        ),
      );
      await tester.pumpAndSettle();

      expect(svc.identityCallCount, 1);
      expect(svc.sessionsCallCount, 1);
      // Exactly one "Retry" affordance for the combined failure, not one
      // under "Verified contacts" and a second under "Active sessions".
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Retry re-invokes both recovery-wrapped loads together', (tester) async {
      final svc = _FlakyProfileService(identityFailTimes: 1, sessionsFailTimes: 1);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: AccountSecurityScreen(profileService: svc)),
        ),
      );
      await tester.pumpAndSettle();

      expect(svc.identityCallCount, 1);
      expect(svc.sessionsCallCount, 1);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(svc.identityCallCount, 2);
      expect(svc.sessionsCallCount, 2);
      expect(find.text('Retry'), findsNothing);
    });
  });
}
