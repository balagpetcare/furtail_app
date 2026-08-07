/// Single canonical source for Public Profile field limits/rules, mirroring
/// the server contract in furtail_app_api's shared-user-profile.ts
/// (BIO_MAX, USERNAME_PATTERN) exactly. Every screen, validator, counter,
/// and help text must read from here — never hard-code a competing limit.
class ProfileValidation {
  const ProfileValidation._();

  /// Mirrors `BIO_MAX` in shared-user-profile.ts.
  static const int bioMaxLength = 280;

  /// Mirrors `USERNAME_PATTERN` validation in shared-user-profile.ts:
  /// 3-30 chars, lowercase letters/digits/underscore. Username is optional.
  static const int usernameMinLength = 3;
  static const int usernameMaxLength = 30;
  static final RegExp usernamePattern = RegExp(r'^[a-z0-9_]+$');
  static const bool usernameRequired = false;

  static const String usernameHelperText =
      'Optional — 3-30 characters, lowercase letters, numbers, or underscores';

  /// Returns a validation error, or null if [value] is acceptable.
  /// Username is optional: an empty value is always valid.
  static String? validateUsername(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    final normalized = v.toLowerCase();
    if (normalized.length < usernameMinLength || normalized.length > usernameMaxLength) {
      return 'Username must be $usernameMinLength-$usernameMaxLength characters';
    }
    if (!usernamePattern.hasMatch(normalized)) {
      return 'Username can only use lowercase letters, numbers, or underscores';
    }
    return null;
  }

  static String? validateBio(String? value) {
    final v = (value ?? '').trim();
    if (v.length > bioMaxLength) {
      return 'Bio must be $bioMaxLength characters or less';
    }
    return null;
  }

  /// True if [username] cannot have been created under the current
  /// validation rule (contains '@', '.', uppercase, or anything outside
  /// [usernamePattern]) — the only way such a value can exist is as a
  /// legacy leftover copied directly from an email address. These must
  /// never be shown as a real public username.
  static bool looksEmailDerived(String? username) {
    final v = (username ?? '').trim();
    if (v.isEmpty) return false;
    if (v.contains('@')) return true;
    return !usernamePattern.hasMatch(v.toLowerCase()) || v != v.toLowerCase();
  }
}
