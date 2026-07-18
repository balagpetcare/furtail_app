import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/features/auth/presentation/widgets/provider_button_grid.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

CentralAuthBootstrap _bootstrap({
  List<CentralAuthProvider> providers = const [],
  List<String> orgs = const [],
  bool emailOtp = false,
}) {
  return CentralAuthBootstrap(
    registrationOpen: true,
    requiredProfileFields: const [],
    loginMethods: CentralAuthLoginMethods(
      emailPassword: true,
      phonePassword: true,
      emailOtp: emailOtp,
      phoneOtp: false,
      whatsappOtp: false,
    ),
    providers: providers,
    enterpriseOrganizations: orgs,
    otpCodeLength: 6,
    otpExpiryMinutes: 5,
    otpResendCooldownSeconds: 30,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders nothing when bootstrap is null', (tester) async {
    await tester.pumpWidget(_wrap(const ProviderButtonGrid(bootstrap: null)));
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('renders nothing when no providers/otp are enabled', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(ProviderButtonGrid(bootstrap: _bootstrap())));
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets(
    'renders only enabled providers; tap without a handler shows honest pending message',
    (tester) async {
      final bootstrap = _bootstrap(
        providers: const [
          CentralAuthProvider(
            id: 'google',
            displayName: 'Google',
            enabled: true,
          ),
          CentralAuthProvider(
            id: 'facebook',
            displayName: 'Facebook',
            enabled: false, // must NOT be rendered
          ),
        ],
      );
      await tester.pumpWidget(_wrap(ProviderButtonGrid(bootstrap: bootstrap)));

      expect(find.textContaining('Google'), findsOneWidget);
      expect(find.textContaining('Facebook'), findsNothing);

      // No onProviderSelected handler supplied → an honest "not available"
      // message, never a silent no-op.
      await tester.tap(find.textContaining('Google'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  testWidgets(
    'wired social provider invokes onProviderSelected with the provider id',
    (tester) async {
      String? selected;
      final bootstrap = _bootstrap(
        providers: const [
          CentralAuthProvider(
            id: 'google',
            displayName: 'Google',
            enabled: true,
          ),
        ],
      );
      await tester.pumpWidget(
        _wrap(
          ProviderButtonGrid(
            bootstrap: bootstrap,
            onProviderSelected: (id) async => selected = id,
          ),
        ),
      );

      await tester.tap(find.textContaining('Google'));
      await tester.pump();
      expect(selected, 'google');
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('OTP option is real (wired) and invokes the callback', (
    tester,
  ) async {
    var otpRequested = false;
    final bootstrap = _bootstrap(emailOtp: true);
    await tester.pumpWidget(
      _wrap(
        ProviderButtonGrid(
          bootstrap: bootstrap,
          onOtpRequested: () => otpRequested = true,
        ),
      ),
    );

    expect(find.textContaining('OTP'), findsOneWidget);
    await tester.tap(find.textContaining('OTP'));
    await tester.pump();
    expect(otpRequested, isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'OIDC enterprise org is wired; SAML org stays honestly disabled',
    (tester) async {
      String? selected;
      final bootstrap = CentralAuthBootstrap(
        registrationOpen: true,
        requiredProfileFields: const [],
        loginMethods: CentralAuthLoginMethods(
          emailPassword: true,
          phonePassword: true,
          emailOtp: false,
          phoneOtp: false,
          whatsappOtp: false,
        ),
        providers: const [],
        enterpriseOrganizations: const ['acme', 'globex'],
        enterpriseOrgDetails: const [
          CentralAuthEnterpriseOrg(
            orgSlug: 'acme',
            displayName: 'Acme Corp',
            protocol: 'OIDC',
          ),
          CentralAuthEnterpriseOrg(
            orgSlug: 'globex',
            displayName: 'Globex',
            protocol: 'SAML',
          ),
        ],
        otpCodeLength: 6,
        otpExpiryMinutes: 5,
        otpResendCooldownSeconds: 30,
      );
      await tester.pumpWidget(
        _wrap(
          ProviderButtonGrid(
            bootstrap: bootstrap,
            onProviderSelected: (id) async => selected = id,
          ),
        ),
      );

      await tester.tap(find.textContaining('Acme Corp'));
      await tester.pump();
      expect(selected, 'enterprise:acme');

      // SAML org renders in the disabled/"soon" state.
      expect(find.textContaining('Globex • soon'), findsOneWidget);
    },
  );

  testWidgets('collapses extra providers under a "More" button', (
    tester,
  ) async {
    final bootstrap = _bootstrap(
      providers: const [
        CentralAuthProvider(id: 'google', displayName: 'Google', enabled: true),
        CentralAuthProvider(
          id: 'facebook',
          displayName: 'Facebook',
          enabled: true,
        ),
        CentralAuthProvider(id: 'apple', displayName: 'Apple', enabled: true),
      ],
      emailOtp: true,
      orgs: const ['acme'],
    );
    await tester.pumpWidget(
      _wrap(ProviderButtonGrid(bootstrap: bootstrap, maxVisible: 2)),
    );

    expect(find.textContaining('acme'), findsNothing);
    final moreButton = find.widgetWithText(OutlinedButton, 'More');
    expect(moreButton, findsOneWidget);

    await tester.tap(moreButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('acme'), findsOneWidget);
  });
}
