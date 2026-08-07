import 'dart:io';

void main() {
  var file1 = File('test/core/auth/auth_controller_test.dart');
  var content1 = file1.readAsStringSync();
  content1 = content1.replaceFirst(
    '  Future<void> revoke(String accessToken) async {}',
    '  Future<void> revoke(String accessToken) async {}\n\n  @override\n  Future<void> confirmPhoneChange({required String code}) => throw UnimplementedError();\n\n  @override\n  Future<void> requestEmailVerification() => throw UnimplementedError();\n\n  @override\n  Future<void> requestPhoneChange({required String phone}) => throw UnimplementedError();\n\n  @override\n  Future<CentralAuthUser> updateProfile({String? displayName, String? dateOfBirth}) => throw UnimplementedError();'
  );
  file1.writeAsStringSync(content1);

  var file2 = File('test/core/auth/auth_interceptor_test.dart');
  var content2 = file2.readAsStringSync();
  content2 = content2.replaceFirst(
    '  Future<void> revoke(String accessToken) async {}',
    '  Future<void> revoke(String accessToken) async {}\n\n  @override\n  Future<void> confirmPhoneChange({required String code}) => throw UnimplementedError();\n\n  @override\n  Future<void> requestEmailVerification() => throw UnimplementedError();\n\n  @override\n  Future<void> requestPhoneChange({required String phone}) => throw UnimplementedError();\n\n  @override\n  Future<CentralAuthUser> updateProfile({String? displayName, String? dateOfBirth}) => throw UnimplementedError();'
  );
  file2.writeAsStringSync(content2);

  var file3 = File('lib/features/profile/presentation/screens/user_profile_screen.dart');
  var content3 = file3.readAsStringSync();
  content3 = content3.replaceAll('<EditProfileResult>', '<bool>');
  content3 = content3.replaceAll('|| !result.updated', '|| result != true');
  content3 = content3.replaceAll('result.warning == null', 'true');
  content3 = content3.replaceFirst('import \'edit_profile_screen.dart\';', 'import \'profile_settings_hub_screen.dart\';');
  file3.writeAsStringSync(content3);
}
