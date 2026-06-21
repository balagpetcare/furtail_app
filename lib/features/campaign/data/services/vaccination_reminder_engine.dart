import '../../data/models/campaign_models.dart';
import '../../../notifications/data/services/notification_service.dart';

/// Vaccine-specific reminder schedules:
/// Cat Flu — 7d, 3d, due today
/// Rabies — 30d, 7d, due today
class VaccinationReminderEngine {
  VaccinationReminderEngine(this._notifications);

  final NotificationService _notifications;

  static const catFluOffsets = [7, 3, 0];
  static const rabiesOffsets = [30, 7, 0];

  Future<void> syncRecords(List<VaccinationRecord> records) async {
    for (final record in records) {
      if (record.nextDueDate == null) continue;
      final offsets = _offsetsForVaccine(record.vaccineType);
      for (final daysBefore in offsets) {
        await _scheduleOne(record, daysBefore);
      }
    }
  }

  List<int> _offsetsForVaccine(String vaccineType) {
    final n = vaccineType.toLowerCase();
    if (n.contains('rabies')) return rabiesOffsets;
    if (n.contains('flu') ||
        n.contains('feline') ||
        n.contains('rhino') ||
        n.contains('calici') ||
        n.contains('purevax')) {
      return catFluOffsets;
    }
    // Default to cat flu schedule for unknown feline vaccines
    return catFluOffsets;
  }

  Future<void> _scheduleOne(VaccinationRecord record, int daysBefore) async {
    final due = record.nextDueDate!;
    final scheduled = DateTime(due.year, due.month, due.day)
        .subtract(Duration(days: daysBefore));
    if (scheduled.isBefore(DateTime.now())) return;

    final label = daysBefore == 0
        ? 'due today'
        : daysBefore == 1
            ? 'due tomorrow'
            : 'due in $daysBefore days';

    await _notifications.scheduleCampaignReminder(
      dedupeKey: 'vax-${record.id}-${record.vaccineType}-$daysBefore',
      title: daysBefore == 0 ? 'Vaccination due today' : 'Vaccination reminder',
      body: '${record.petName}: ${record.vaccineType} $label',
      scheduledDate: scheduled,
      actionUrl: 'campaign/detail/vaccination',
    );
  }
}
