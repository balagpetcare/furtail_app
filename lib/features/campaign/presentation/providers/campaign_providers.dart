import 'package:bpa_app/features/notifications/presentation/providers/notification_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bpa_app/services/api_client.dart';
import '../../data/models/campaign_models.dart';
import '../../data/repositories/campaign_repository.dart';
import '../../data/services/certificate_share_service.dart';
import '../../data/services/reminder_storage.dart';
import '../utils/campaign_health_utils.dart';

final campaignRepositoryProvider = Provider<CampaignRepository>((ref) {
  return CampaignRepository(ref.read(apiClientProvider));
});

final reminderStorageProvider = Provider<ReminderStorage>((ref) {
  return ReminderStorage();
});

final campaignSummaryProvider = FutureProvider<CampaignLinkSummary>((ref) async {
  return ref.read(campaignRepositoryProvider).fetchSummary();
});

final myCampaignBookingsProvider = FutureProvider<List<CampaignBooking>>((ref) async {
  return ref.read(campaignRepositoryProvider).fetchMyBookings();
});

final vaccinationRecordsProvider = FutureProvider<List<VaccinationRecord>>((ref) async {
  return ref.read(campaignRepositoryProvider).fetchVaccinations();
});

final upcomingVaccinationsProvider = FutureProvider<List<UpcomingVaccination>>((ref) async {
  return ref.read(campaignRepositoryProvider).fetchUpcoming();
});

final campaignBenefitsProvider = FutureProvider<CampaignBenefits>((ref) async {
  return ref.read(campaignRepositoryProvider).fetchBenefits();
});

final vaccinationRemindersProvider =
    AsyncNotifierProvider<VaccinationRemindersNotifier, List<VaccinationReminder>>(
  VaccinationRemindersNotifier.new,
);

class VaccinationRemindersNotifier extends AsyncNotifier<List<VaccinationReminder>> {
  @override
  Future<List<VaccinationReminder>> build() async {
    final storage = ref.read(reminderStorageProvider);
    final saved = await storage.load();
    if (saved.isNotEmpty) return saved;

    final records = await ref.read(vaccinationRecordsProvider.future);
    final generated = records
        .where((r) => r.nextDueDate != null)
        .map(
          (r) => VaccinationReminder(
            id: 'due-${r.id}',
            petName: r.petName,
            vaccineType: r.vaccineType,
            dueDate: r.nextDueDate!,
            enabled: true,
          ),
        )
        .toList();
    await storage.save(generated);
    await _syncLocalReminders(ref, generated);
    return generated;
  }

  Future<void> toggle(String id, bool enabled) async {
    final current = state.valueOrNull ?? await future;
    final updated = current
        .map((r) => r.id == id ? VaccinationReminder(
              id: r.id,
              petName: r.petName,
              vaccineType: r.vaccineType,
              dueDate: r.dueDate,
              enabled: enabled,
              daysBefore: r.daysBefore,
            ) : r)
        .toList();
    state = AsyncData(updated);
    await ref.read(reminderStorageProvider).save(updated);
    await _syncLocalReminders(ref, updated);
  }

  Future<void> refreshFromRecords() async {
    ref.invalidate(vaccinationRecordsProvider);
    final records = await ref.read(vaccinationRecordsProvider.future);
    final existing = state.valueOrNull ?? [];
    final merged = <VaccinationReminder>[];

    for (final r in records.where((e) => e.nextDueDate != null)) {
      final id = 'due-${r.id}';
      VaccinationReminder? prev;
      for (final e in existing) {
        if (e.id == id) {
          prev = e;
          break;
        }
      }
      merged.add(
        VaccinationReminder(
          id: id,
          petName: r.petName,
          vaccineType: r.vaccineType,
          dueDate: r.nextDueDate!,
          enabled: prev?.enabled ?? true,
          daysBefore: prev?.daysBefore ?? 7,
        ),
      );
    }

    state = AsyncData(merged);
    await ref.read(reminderStorageProvider).save(merged);
    await _syncLocalReminders(ref, merged);
  }
}

Future<void> _syncLocalReminders(
  Ref ref,
  List<VaccinationReminder> reminders,
) async {
  try {
    await ref.read(notificationControllerProvider.future);
    await ref
        .read(notificationControllerProvider.notifier)
        .syncVaccinationReminders(reminders);
  } catch (_) {}
}

final certificateProvider =
    FutureProvider.family<CertificateData, String>((ref, token) async {
  return ref.read(campaignRepositoryProvider).fetchCertificate(token);
});

final certificateShareServiceProvider = Provider<CertificateShareService>((ref) {
  return CertificateShareService(ref.read(campaignRepositoryProvider));
});

/// Filter key for pet-scoped campaign health data.
class PetHealthFilter {
  final int petId;
  final String? petName;
  const PetHealthFilter({required this.petId, this.petName});

  @override
  bool operator ==(Object other) =>
      other is PetHealthFilter && other.petId == petId && other.petName == petName;

  @override
  int get hashCode => Object.hash(petId, petName);
}

/// Vaccination records filtered for a permanent pet profile.
final petVaccinationRecordsProvider =
    FutureProvider.family<List<VaccinationRecord>, PetHealthFilter>((ref, filter) async {
  final all = await ref.read(vaccinationRecordsProvider.future);
  return recordsForPet(all, petId: filter.petId, petName: filter.petName);
});
