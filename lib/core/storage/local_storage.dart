import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _kUserName = 'userName';
  static const _kUserEmail = 'userEmail';
  // Used for ownership checks (Edit/Delete post).
  static const _kUserId = 'userId';
  // Optional: used in UI (comments, header avatars).
  static const _kAvatarUrl = 'avatarUrl';
  static const _kLocale = 'locale'; // 'en' | 'bn'
  static const _kThemeMode = 'theme_mode'; // 'light' | 'dark' | 'system'
  /// Phase 5: Country code for API (X-Country-Code). e.g. BD, IN, US
  static const _kCountryCode = 'furtail_country_code';
  /// Phase 5: State/Province code for API (X-State-Code)
  static const _kStateCode = 'furtail_state_code';

  /// Populates the display-cache fields (name/email/id/avatar) still read
  /// synchronously by several preserved domain screens for ownership checks
  /// and header display. Called by `AuthController` after bootstrap/login
  /// succeeds against the Central Auth `/me` response.
  ///
  /// Deliberately does NOT store a token — the OAuth2 access/refresh tokens
  /// are owned exclusively by `SecureStorageService` (flutter_secure_storage)
  /// since the Central Auth migration; this is display data only.
  static Future<void> cacheUserDisplayInfo({
    required int userId,
    required String userName,
    required String userEmail,
    String? avatarUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUserId, userId);
    await prefs.setString(_kUserName, userName);
    await prefs.setString(_kUserEmail, userEmail);
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      await prefs.setString(_kAvatarUrl, avatarUrl.trim());
    } else {
      await prefs.remove(_kAvatarUrl);
    }
  }

  static Future<void> clearUserDisplayInfo() async {
    final prefs = await SharedPreferences.getInstance();
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

  static Future<void> migrateLegacyPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Country Code migration
    if (prefs.containsKey('bpa_country_code') && !prefs.containsKey(_kCountryCode)) {
      final value = prefs.getString('bpa_country_code');
      if (value != null) {
        await prefs.setString(_kCountryCode, value);
      }
      await prefs.remove('bpa_country_code');
    } else if (prefs.containsKey('wpa_country_code') && !prefs.containsKey(_kCountryCode)) {
      final value = prefs.getString('wpa_country_code');
      if (value != null) {
        await prefs.setString(_kCountryCode, value);
      }
      await prefs.remove('wpa_country_code');
    }
    
    // State Code migration
    if (prefs.containsKey('bpa_state_code') && !prefs.containsKey(_kStateCode)) {
      final value = prefs.getString('bpa_state_code');
      if (value != null) {
        await prefs.setString(_kStateCode, value);
      }
      await prefs.remove('bpa_state_code');
    } else if (prefs.containsKey('wpa_state_code') && !prefs.containsKey(_kStateCode)) {
      final value = prefs.getString('wpa_state_code');
      if (value != null) {
        await prefs.setString(_kStateCode, value);
      }
      await prefs.remove('wpa_state_code');
    }

    // FCM Token migrations
    if (prefs.containsKey('bpa_fcm_token') && !prefs.containsKey('furtail_fcm_token')) {
      final tokenValue = prefs.getString('bpa_fcm_token');
      if (tokenValue != null) {
        await prefs.setString('furtail_fcm_token', tokenValue);
      }
      await prefs.remove('bpa_fcm_token');
    } else if (prefs.containsKey('wpa_fcm_token') && !prefs.containsKey('furtail_fcm_token')) {
      final tokenValue = prefs.getString('wpa_fcm_token');
      if (tokenValue != null) {
        await prefs.setString('furtail_fcm_token', tokenValue);
      }
      await prefs.remove('wpa_fcm_token');
    }

    if (prefs.containsKey('bpa_fcm_token_synced') && !prefs.containsKey('furtail_fcm_token_synced')) {
      final syncedValue = prefs.getBool('bpa_fcm_token_synced');
      if (syncedValue != null) {
        await prefs.setBool('furtail_fcm_token_synced', syncedValue);
      }
      await prefs.remove('bpa_fcm_token_synced');
    } else if (prefs.containsKey('wpa_fcm_token_synced') && !prefs.containsKey('furtail_fcm_token_synced')) {
      final syncedValue = prefs.getBool('wpa_fcm_token_synced');
      if (syncedValue != null) {
        await prefs.setBool('furtail_fcm_token_synced', syncedValue);
      }
      await prefs.remove('wpa_fcm_token_synced');
    }
  }
}
