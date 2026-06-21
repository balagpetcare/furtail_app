import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _kToken = 'token';
  static const _kUserName = 'userName';
  static const _kUserEmail = 'userEmail';
  // Used for ownership checks (Edit/Delete post).
  static const _kUserId = 'userId';
  // Optional: used in UI (comments, header avatars).
  static const _kAvatarUrl = 'avatarUrl';
  static const _kLocale = 'locale'; // 'en' | 'bn'
  static const _kThemeMode = 'theme_mode'; // 'light' | 'dark' | 'system'
  /// Phase 5: Country code for API (X-Country-Code). e.g. BD, IN, US
  static const _kCountryCode = 'bpa_country_code';
  /// Phase 5: State/Province code for API (X-State-Code)
  static const _kStateCode = 'bpa_state_code';

  static Future<void> saveAuth({
    required String token,
    required String userName,
    required String userEmail,
    int? userId,
    String? avatarUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kUserName, userName);
    await prefs.setString(_kUserEmail, userEmail);

    // Keep these optional for backward compatibility.
    if (userId != null) {
      await prefs.setInt(_kUserId, userId);
    }
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      await prefs.setString(_kAvatarUrl, avatarUrl.trim());
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUserName);
    await prefs.remove(_kUserEmail);
    await prefs.remove(_kUserId);
    await prefs.remove(_kAvatarUrl);
  }

  // -----------------------------
  // Current user helpers
  // -----------------------------
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kUserId);
  }

  static Future<String?> getAvatarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAvatarUrl);
  }

  // -----------------------------
  // Locale
  // -----------------------------
  static Future<void> setLocaleCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocale, code);
  }

  static Future<String?> getLocaleCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLocale);
  }

  // -----------------------------
  // Theme mode
  // -----------------------------
  static Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode);
  }

  static Future<String?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kThemeMode);
  }

  // -----------------------------
  // Phase 5: Country (X-Country-Code)
  // -----------------------------
  static Future<void> setCountryCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCountryCode, code.toUpperCase().trim());
  }

  static Future<String?> getCountryCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCountryCode);
  }

  static Future<void> setStateCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStateCode, code.toUpperCase().trim());
  }

  static Future<String?> getStateCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kStateCode);
  }
}
