/// Masks an OTP recipient (email or phone) for display on the OTP-entry
/// screen, e.g. `j***@example.com` or `01***-***45`. Shared by every OTP
/// context (login/register/forgot-password) so masking logic lives in one
/// place instead of being duplicated per screen.
abstract final class OtpDestinationMasking {
  /// Masks [recipient] according to [channel] (`'email'`, `'phone'`, or
  /// `'whatsapp'` — phone and whatsapp use the same phone-shaped masking).
  static String mask(String channel, String recipient) {
    final trimmed = recipient.trim();
    if (trimmed.isEmpty) return trimmed;
    if (channel == 'email') return maskEmail(trimmed);
    return maskPhone(trimmed);
  }

  /// `jane.doe@example.com` -> `j***@example.com`. Falls back to masking the
  /// whole local part for very short local parts (e.g. `a@b.com` -> `a@b.com`
  /// stays readable rather than becoming an empty prefix).
  static String maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    final local = email.substring(0, at);
    final domain = email.substring(at);
    if (local.length <= 1) return '$local$domain';
    return '${local.substring(0, 1)}***$domain';
  }

  /// `01712345678` -> `017***5678`; `+8801712345678` -> `+880***5678`.
  /// Keeps a short recognizable prefix (country code / leading digits) and
  /// the last 4 digits, masking everything between.
  static String maskPhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\s|-'), '');
    if (digitsOnly.length <= 6) return digitsOnly;
    final prefixLen = digitsOnly.startsWith('+') ? 4 : 3;
    final prefix = digitsOnly.substring(0, prefixLen);
    final suffix = digitsOnly.substring(digitsOnly.length - 4);
    return '$prefix***$suffix';
  }
}
