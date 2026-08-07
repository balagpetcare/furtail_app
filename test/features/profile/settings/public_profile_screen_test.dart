import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/features/profile/data/models/user_profile_model.dart';
import 'package:furtail_app/features/profile/data/profile_service.dart';
import 'package:furtail_app/features/profile/presentation/screens/settings/public_profile_screen.dart';
import 'package:furtail_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fails the test if [getAccountIdentity] or [updateIdentity] (Central
/// Auth) is ever invoked — Public Profile owns displayName/username/bio
/// entirely through Furtail and must never touch Central Auth to render or
/// save this screen.
class _FakeProfileService extends ProfileService {
  _FakeProfileService({this.updateError, this.updatedProfile});

  final ApiClientException? updateError;
  final UserProfileModel? updatedProfile;
  Map<String, dynamic>? lastPayload;
  int updateProfileCallCount = 0;

  @override
  Future<CentralAuthUser> getAccountIdentity() async {
    throw StateError('Public Profile must never call Central Auth getAccountIdentity()');
  }

  @override
  Future<CentralAuthUser> updateIdentity({
    String? displayName,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
  }) async {
    throw StateError('Public Profile must never call Central Auth updateIdentity()');
  }

  @override
  Future<UserProfileModel> updateProfile(Map<String, dynamic> payload) async {
    updateProfileCallCount += 1;
    lastPayload = payload;
    if (updateError != null) throw updateError!;
    return updatedProfile!;
  }
}

UserProfileModel _profile({
  String name = 'Puti Parent',
  String? username = 'puti_parent',
  String? bio = 'Loves rescued pets.',
}) {
  return UserProfileModel(
    id: 42,
    name: name,
    email: 'owner@example.com',
    phone: '+8801000000000',
    username: username,
    bio: bio,
    points: 0,
    balance: 0,
    followers: 0,
    following: 0,
    followerPreviewUrls: const <String>[],
    photoUrl: '',
    coverUrl: '',
    pets: const [],
    galleryUrls: const <String>[],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('titles the page "Public profile" and never touches Central Auth', (tester) async {
    final service = _FakeProfileService(updatedProfile: _profile());

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PublicProfileScreen(initial: _profile(), profileService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Public profile'), findsOneWidget);
    expect(find.text('Account identity'), findsNothing);
  });

  testWidgets('maps typed username conflict beside the username field', (tester) async {
    final service = _FakeProfileService(
      updateError: ApiClientException(
        message: 'Username already taken',
        statusCode: 409,
        responseData: {
          'error': {
            'details': {'field': 'username'},
          },
        },
      ),
      updatedProfile: _profile(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PublicProfileScreen(initial: _profile(), profileService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'taken_name');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(service.updateProfileCallCount, 1);
    final decorator = tester.widget<InputDecorator>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Username'),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(decorator.decoration.errorText, 'Username already taken');
  });

  testWidgets('profile header never falls back to email when username is absent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileHeader(profile: _profile(username: null))),
      ),
    );

    expect(find.text('owner@example.com'), findsNothing);
    expect(find.text('Furtail Member'), findsOneWidget);
  });

  testWidgets('saves displayName, username and bio only through Furtail updateProfile', (
    tester,
  ) async {
    final service = _FakeProfileService(updatedProfile: _profile());

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PublicProfileScreen(initial: _profile(), profileService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Bio'), 'Updated bio text');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(service.updateProfileCallCount, 1);
    expect(service.lastPayload, isNotNull);
    expect(service.lastPayload!.containsKey('displayName'), isTrue);
    expect(service.lastPayload!.containsKey('username'), isTrue);
    expect(service.lastPayload!['bio'], 'Updated bio text');
    // Never sends any Central-Auth-owned identity field.
    expect(service.lastPayload!.containsKey('birthdate'), isFalse);
    expect(service.lastPayload!.containsKey('firstName'), isFalse);
    expect(service.lastPayload!.containsKey('lastName'), isFalse);
  });

  testWidgets('preserves dirty values after a save failure (no pop, no clearing)', (tester) async {
    final service = _FakeProfileService(
      updateError: ApiClientException(message: 'Server error', statusCode: 500),
      updatedProfile: _profile(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PublicProfileScreen(initial: _profile(), profileService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Bio'), 'Retry check');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(PublicProfileScreen), findsOneWidget);
    final bioField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Bio'));
    expect(bioField.controller?.text, 'Retry check');
  });

  testWidgets('canonical bio limit is 280, matching the server contract', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PublicProfileScreen(
            initial: _profile(),
            profileService: _FakeProfileService(updatedProfile: _profile()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Bio'), 'x' * 300);
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Bio'),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.controller.text.length, 280);
  });

  testWidgets('suppresses a legacy email-derived username and prompts to choose one', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PublicProfileScreen(
            initial: _profile(username: 'owner@example.com'),
            profileService: _FakeProfileService(updatedProfile: _profile()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final usernameField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Username'),
    );
    expect(usernameField.controller?.text, isEmpty);
    expect(find.textContaining('Choose a username'), findsOneWidget);
  });
}
