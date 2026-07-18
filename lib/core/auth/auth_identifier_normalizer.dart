enum AuthIdentifierType { email, mobile, username }

class NormalizedAuthIdentifier {
  const NormalizedAuthIdentifier({required this.type, required this.value});

  final AuthIdentifierType type;
  final String value;
}

class BangladeshPhoneNormalizationException implements Exception {
  const BangladeshPhoneNormalizationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Normalizes a login identifier the same way BPA User App does, since both
/// apps authenticate against the same Central Auth API (`/auth/login`
/// matches `emailOrUsername` against `username`, `email`, OR `phone`
/// columns directly).
class AuthIdentifierNormalizer {
  AuthIdentifierNormalizer._();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _bdMobilePattern = RegExp(r'^01[3-9]\d{8}$');
  static final _numericLikePattern = RegExp(r'^[\d\s\-\+\(\)\.]+$');

  static bool isValidEmail(String value) =>
      _emailPattern.hasMatch(value.trim());

  static bool looksLikeMobileCandidate(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty &&
        (_numericLikePattern.hasMatch(trimmed) || trimmed.startsWith('+'));
  }

  static String normalizeBangladeshPhone(String input) {
    final trimmed = input.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 10 && digits.startsWith('1')) {
      final normalized = '0$digits';
      if (_bdMobilePattern.hasMatch(normalized)) return normalized;
    }

    if (digits.length == 11 && _bdMobilePattern.hasMatch(digits)) {
      return digits;
    }

    if (digits.length == 13 && digits.startsWith('880')) {
      final normalized = '0${digits.substring(3)}';
      if (_bdMobilePattern.hasMatch(normalized)) return normalized;
    }

    throw const BangladeshPhoneNormalizationException(
      'Enter a valid Bangladeshi mobile number',
    );
  }

  /// Historical alternate stored format (`+880XXXXXXXXXX`) for legacy
  /// accounts registered before the canonical local format
  /// (`01XXXXXXXXXX`) was enforced.
  static String toAlternateBangladeshPhone(String canonicalLocal) {
    return '+880${canonicalLocal.substring(1)}';
  }

  static NormalizedAuthIdentifier normalizeForLogin(String input) {
    final trimmed = input.trim();

    if (trimmed.contains('@')) {
      if (!isValidEmail(trimmed)) {
        throw const BangladeshPhoneNormalizationException(
          'Enter a valid email address',
        );
      }
      return NormalizedAuthIdentifier(
        type: AuthIdentifierType.email,
        value: trimmed.toLowerCase(),
      );
    }

    if (looksLikeMobileCandidate(trimmed)) {
      return NormalizedAuthIdentifier(
        type: AuthIdentifierType.mobile,
        value: normalizeBangladeshPhone(trimmed),
      );
    }

    return NormalizedAuthIdentifier(
      type: AuthIdentifierType.username,
      value: trimmed,
    );
  }
}
