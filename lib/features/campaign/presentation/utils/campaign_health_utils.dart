import '../../data/models/campaign_models.dart';

/// Timeline event for vaccination + campaign history UI.
class VaccinationTimelineEvent {
  final String id;
  final VaccinationTimelineEventType type;
  final DateTime? at;
  final String title;
  final String subtitle;
  final String? certificateToken;
  final int? petId;
  final String petName;

  const VaccinationTimelineEvent({
    required this.id,
    required this.type,
    required this.at,
    required this.title,
    required this.subtitle,
    this.certificateToken,
    this.petId,
    required this.petName,
  });
}

enum VaccinationTimelineEventType {
  vaccination,
  booking,
  checkIn,
  completed,
}

List<VaccinationRecord> recordsForPet(
  List<VaccinationRecord> all, {
  required int petId,
  String? petName,
}) {
  return all.where((r) {
    if (r.petId == petId) return true;
    if (petName != null &&
        r.petId == null &&
        r.petName.toLowerCase() == petName.toLowerCase()) {
      return true;
    }
    return false;
  }).toList();
}

List<VaccinationTimelineEvent> buildVaccinationTimeline({
  required List<VaccinationRecord> records,
  List<CampaignBooking> bookings = const [],
  int? petId,
  String? petName,
}) {
  final events = <VaccinationTimelineEvent>[];

  Iterable<VaccinationRecord> recs = records;
  if (petId != null) {
    recs = recordsForPet(records, petId: petId, petName: petName);
  }

  for (final r in recs) {
    if (r.administeredAt != null) {
      events.add(
        VaccinationTimelineEvent(
          id: 'vac-${r.id}',
          type: VaccinationTimelineEventType.vaccination,
          at: r.administeredAt,
          title: r.vaccineType,
          subtitle: [
            if (r.campaignName != null) r.campaignName,
            if (r.location != null) r.location,
          ].whereType<String>().join(' · '),
          certificateToken: r.certificateToken,
          petId: r.petId,
          petName: r.petName,
        ),
      );
    }
  }

  Iterable<CampaignBooking> books = bookings;
  if (petId != null || petName != null) {
    books = bookings.where((b) {
      return b.pets.any((p) {
        // Bookings may not expose permanentPetId; match pet name
        if (petName != null && p.name.toLowerCase() == petName.toLowerCase()) {
          return true;
        }
        return false;
      });
    });
  }

  for (final b in books) {
    if (b.bookingDate != null) {
      events.add(
        VaccinationTimelineEvent(
          id: 'book-${b.id}',
          type: VaccinationTimelineEventType.booking,
          at: b.bookingDate,
          title: 'Campaign booking',
          subtitle: '${b.campaignName ?? "Campaign"} · ${b.locationName ?? b.coverageZoneName ?? "Venue pending"}',
          petId: petId,
          petName: b.pets.isNotEmpty ? b.pets.first.name : 'Pet',
        ),
      );
    }
    if (b.checkedInAt != null) {
      events.add(
        VaccinationTimelineEvent(
          id: 'checkin-${b.id}',
          type: VaccinationTimelineEventType.checkIn,
          at: b.checkedInAt,
          title: 'Clinic check-in',
          subtitle: b.bookingRef,
          petId: petId,
          petName: b.pets.isNotEmpty ? b.pets.first.name : 'Pet',
        ),
      );
    }
    if (b.completedAt != null) {
      events.add(
        VaccinationTimelineEvent(
          id: 'done-${b.id}',
          type: VaccinationTimelineEventType.completed,
          at: b.completedAt,
          title: 'Visit completed',
          subtitle: b.bookingRef,
          petId: petId,
          petName: b.pets.isNotEmpty ? b.pets.first.name : 'Pet',
        ),
      );
    }
  }

  events.sort((a, b) {
    final ta = a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
    final tb = b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
    return tb.compareTo(ta);
  });

  return events;
}

List<VaccinationRecord> recordsWithCertificates(List<VaccinationRecord> records) {
  return records.where((r) => r.certificateToken != null && r.certificateToken!.isNotEmpty).toList();
}
