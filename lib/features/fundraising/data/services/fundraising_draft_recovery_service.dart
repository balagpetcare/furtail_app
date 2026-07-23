import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/fundraising_draft_models.dart';

class FundraisingDraftRecoveryService {
  FundraisingDraftRecoveryService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _draftKey = 'fundraising_wizard_recovery_v2';

  Future<FundraisingDraftRecovery?> load() async {
    final raw = await _storage.read(key: _draftKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return FundraisingDraftRecovery.fromEncoded(raw);
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(FundraisingDraftRecovery recovery) {
    return _storage.write(key: _draftKey, value: recovery.encode());
  }

  Future<void> clear() {
    return _storage.delete(key: _draftKey);
  }
}
