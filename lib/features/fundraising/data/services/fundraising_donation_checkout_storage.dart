import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/fundraising_donation_models.dart';

class FundraisingDonationCheckoutStorage {
  FundraisingDonationCheckoutStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _recordsKey = 'fundraising_donation_checkout_records_v1';
  static const String _activeAttemptKey =
      'fundraising_donation_checkout_active_attempt_v1';

  Future<List<FundraisingDonationCheckoutRecord>> loadAll() async {
    final raw = await _storage.read(key: _recordsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <FundraisingDonationCheckoutRecord>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <FundraisingDonationCheckoutRecord>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => FundraisingDonationCheckoutRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      await clearAll();
      return const <FundraisingDonationCheckoutRecord>[];
    }
  }

  Future<FundraisingDonationCheckoutRecord?> loadByAttemptId(
    String attemptId,
  ) async {
    final all = await loadAll();
    for (final item in all) {
      if (item.attemptId == attemptId) {
        return item;
      }
    }
    return null;
  }

  Future<void> upsert(FundraisingDonationCheckoutRecord record) async {
    final all = await loadAll();
    final updated = <FundraisingDonationCheckoutRecord>[
      record,
      ...all.where((item) => item.attemptId != record.attemptId),
    ];
    await _storage.write(
      key: _recordsKey,
      value: jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> setActiveAttemptId(String? attemptId) async {
    if (attemptId == null || attemptId.trim().isEmpty) {
      await _storage.delete(key: _activeAttemptKey);
      return;
    }
    await _storage.write(key: _activeAttemptKey, value: attemptId.trim());
  }

  Future<String?> getActiveAttemptId() async {
    return _storage.read(key: _activeAttemptKey);
  }

  Future<FundraisingDonationCheckoutRecord?> loadActiveAttempt() async {
    final attemptId = await getActiveAttemptId();
    if (attemptId == null || attemptId.trim().isEmpty) return null;
    return loadByAttemptId(attemptId);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _recordsKey);
    await _storage.delete(key: _activeAttemptKey);
  }
}
