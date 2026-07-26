import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FundraisingVerificationRecoveryService {
  FundraisingVerificationRecoveryService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _key = 'fundraising_verification_recovery_v1';

  Future<Map<String, dynamic>?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      await clear();
    }
    return null;
  }

  Future<void> save(Map<String, dynamic> data) async {
    await _storage.write(key: _key, value: jsonEncode(data));
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
