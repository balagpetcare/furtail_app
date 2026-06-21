import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/campaign_models.dart';

class ReminderStorage {
  static const _key = 'campaign_vaccination_reminders';

  Future<List<VaccinationReminder>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => VaccinationReminder.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<VaccinationReminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(reminders.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  Future<void> upsert(VaccinationReminder reminder) async {
    final list = await load();
    final idx = list.indexWhere((r) => r.id == reminder.id);
    if (idx >= 0) {
      list[idx] = reminder;
    } else {
      list.add(reminder);
    }
    await save(list);
  }

  Future<void> remove(String id) async {
    final list = await load()..removeWhere((r) => r.id == id);
    await save(list);
  }
}
