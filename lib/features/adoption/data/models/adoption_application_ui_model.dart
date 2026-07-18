import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';

class AdoptionApplicationUiModel {
  final int id;
  final String status;
  final String rawStatus;
  final String submittedAtLabel;
  final DateTime? submittedAt;
  final AdoptionPetUiModel pet;
  final String applicantName;
  final String applicantUsername;
  final String applicantAvatarUrl;
  final String applicantPhone;
  final String applicantWhatsappPhone;
  final String applicantCityAreaText;
  final String applicantAddress;
  final String message;
  final List<Map<String, dynamic>> answers;
  final bool consentToHomeCheck;
  final bool consentToFollowUp;
  final String applicantExperienceSummary;
  final String applicantHouseholdSummary;
  final String applicantOtherPetsSummary;
  final String applicantOccupation;
  final String ownerNotes;
  final String rejectedReason;

  const AdoptionApplicationUiModel({
    required this.id,
    required this.status,
    required this.rawStatus,
    required this.submittedAtLabel,
    this.submittedAt,
    required this.pet,
    required this.applicantName,
    required this.applicantUsername,
    required this.applicantAvatarUrl,
    required this.applicantPhone,
    required this.applicantWhatsappPhone,
    required this.applicantCityAreaText,
    required this.applicantAddress,
    required this.message,
    required this.answers,
    this.consentToHomeCheck = false,
    this.consentToFollowUp = false,
    this.applicantExperienceSummary = '',
    this.applicantHouseholdSummary = '',
    this.applicantOtherPetsSummary = '',
    this.applicantOccupation = '',
    this.ownerNotes = '',
    this.rejectedReason = '',
  });

  static AdoptionApplicationUiModel fromApiJson(Map<String, dynamic> json) {
    final petJson = json['pet'];
    final pet = petJson is Map<String, dynamic>
        ? AdoptionPetUiModel.fromApiJson(petJson)
        : AdoptionPetUiModel.fromApiJson(json);

    final applicant = json['applicant'] as Map<String, dynamic>?;
    final profile = applicant?['profile'] as Map<String, dynamic>?;
    final avatar = profile?['avatarMedia'] as Map<String, dynamic>?;

    final rawAnswers = json['answers'] as List? ?? const [];
    final answersList = rawAnswers
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final rawSubmittedAt = _asString(json['submittedAt']).isNotEmpty
        ? _asString(json['submittedAt'])
        : _asString(json['createdAt']);

    return AdoptionApplicationUiModel(
      id: _asInt(json['id']),
      rawStatus: _asString(json['status']),
      status: _statusLabel(_asString(json['status'])),
      submittedAtLabel: _dateLabel(rawSubmittedAt),
      submittedAt: DateTime.tryParse(rawSubmittedAt)?.toLocal(),
      pet: pet,
      applicantName: _asString(
        profile?['displayName'] ?? json['applicantName'] ?? 'Anonymous',
      ),
      applicantUsername: _asString(
        profile?['username'] ?? json['applicantUsername'] ?? '',
      ),
      applicantAvatarUrl: _asString(
        avatar?['url'] ?? json['applicantAvatarUrl'] ?? '',
      ),
      applicantPhone: _asString(json['applicantPhone']),
      applicantWhatsappPhone: _asString(json['applicantWhatsappPhone']),
      applicantCityAreaText: _asString(json['applicantCityAreaText']),
      applicantAddress: _asString(json['applicantAddress']),
      message: _asString(json['messageToOwner'] ?? json['message'] ?? ''),
      answers: answersList,
      consentToHomeCheck: _asBool(json['consentToHomeCheck']),
      consentToFollowUp: _asBool(json['consentToFollowUp']),
      applicantExperienceSummary: _asString(json['applicantExperienceSummary']),
      applicantHouseholdSummary: _asString(json['applicantHouseholdSummary']),
      applicantOtherPetsSummary: _asString(json['applicantOtherPetsSummary']),
      applicantOccupation: _asString(json['applicantOccupation']),
      ownerNotes: _asString(json['ownerNotes']),
      rejectedReason: _asString(json['rejectedReason']),
    );
  }

  AdoptionApplicationUiModel copyWith({String? ownerNotes, String? rawStatus, String? status}) {
    return AdoptionApplicationUiModel(
      id: id,
      status: status ?? this.status,
      rawStatus: rawStatus ?? this.rawStatus,
      submittedAtLabel: submittedAtLabel,
      submittedAt: submittedAt,
      pet: pet,
      applicantName: applicantName,
      applicantUsername: applicantUsername,
      applicantAvatarUrl: applicantAvatarUrl,
      applicantPhone: applicantPhone,
      applicantWhatsappPhone: applicantWhatsappPhone,
      applicantCityAreaText: applicantCityAreaText,
      applicantAddress: applicantAddress,
      message: message,
      answers: answers,
      consentToHomeCheck: consentToHomeCheck,
      consentToFollowUp: consentToFollowUp,
      applicantExperienceSummary: applicantExperienceSummary,
      applicantHouseholdSummary: applicantHouseholdSummary,
      applicantOtherPetsSummary: applicantOtherPetsSummary,
      applicantOccupation: applicantOccupation,
      ownerNotes: ownerNotes ?? this.ownerNotes,
      rejectedReason: rejectedReason,
    );
  }

  static String _statusLabel(String value) {
    if (value.isEmpty) return 'Submitted';
    return value
        .toLowerCase()
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  static String _dateLabel(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return 'Date unavailable';
    final local = parsed.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  static int _asInt(dynamic value) =>
      int.tryParse(value?.toString() ?? '') ?? 0;
  static String _asString(dynamic value) => value?.toString().trim() ?? '';
  static bool _asBool(dynamic value) =>
      value == true || value?.toString() == 'true' || value == 1;
}
