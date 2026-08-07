import 'dart:io';

void main() {
  var file1 = File('test/core/auth/auth_controller_test.dart');
  var content1 = file1.readAsStringSync();
  content1 = content1.replaceAll(
    '@override\n  Future<void> confirmPhoneChange({required String code}) => throw UnimplementedError();',
    '@override\n  Future<void> confirmPhoneChange({required String accessToken, required String code}) => throw UnimplementedError();'
  );
  content1 = content1.replaceAll(
    '@override\n  Future<void> requestEmailVerification() => throw UnimplementedError();',
    '@override\n  Future<void> requestEmailVerification({required String accessToken, required String email}) => throw UnimplementedError();'
  );
  content1 = content1.replaceAll(
    '@override\n  Future<void> requestPhoneChange({required String phone}) => throw UnimplementedError();',
    '@override\n  Future<void> requestPhoneChange({required String accessToken, required String phone}) => throw UnimplementedError();'
  );
  content1 = content1.replaceAll(
    '@override\n  Future<CentralAuthUser> updateProfile({String? displayName, String? dateOfBirth}) => throw UnimplementedError();',
    '@override\n  Future<CentralAuthUser> updateProfile({required String accessToken, DateTime? dateOfBirth, String? displayName, String? firstName, String? lastName}) => throw UnimplementedError();'
  );
  file1.writeAsStringSync(content1);

  var file2 = File('test/core/auth/auth_interceptor_test.dart');
  var content2 = file2.readAsStringSync();
  content2 = content2.replaceAll(
    '@override\n  Future<void> confirmPhoneChange({required String code}) => throw UnimplementedError();',
    '@override\n  Future<void> confirmPhoneChange({required String accessToken, required String code}) => throw UnimplementedError();'
  );
  content2 = content2.replaceAll(
    '@override\n  Future<void> requestEmailVerification() => throw UnimplementedError();',
    '@override\n  Future<void> requestEmailVerification({required String accessToken, required String email}) => throw UnimplementedError();'
  );
  content2 = content2.replaceAll(
    '@override\n  Future<void> requestPhoneChange({required String phone}) => throw UnimplementedError();',
    '@override\n  Future<void> requestPhoneChange({required String accessToken, required String phone}) => throw UnimplementedError();'
  );
  content2 = content2.replaceAll(
    '@override\n  Future<CentralAuthUser> updateProfile({String? displayName, String? dateOfBirth}) => throw UnimplementedError();',
    '@override\n  Future<CentralAuthUser> updateProfile({required String accessToken, DateTime? dateOfBirth, String? displayName, String? firstName, String? lastName}) => throw UnimplementedError();'
  );
  file2.writeAsStringSync(content2);

  var file3 = File('lib/features/profile/presentation/screens/user_profile_screen.dart');
  var content3 = file3.readAsStringSync();
  content3 = content3.replaceAll(
    '''
          true
              ? 'Profile updated successfully.'
              : 'Profile updated with warnings: \'
''',
    '''
          'Profile updated successfully.'
'''
  );
  file3.writeAsStringSync(content3);
}
