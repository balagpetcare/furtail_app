import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';

class AdoptionApplicationUiModel {
  final int id;
  final String status;
  final String submittedAtLabel;
  final AdoptionPetUiModel pet;

  const AdoptionApplicationUiModel({
    required this.id,
    required this.status,
    required this.submittedAtLabel,
    required this.pet,
  });

  static AdoptionApplicationUiModel fromApiJson(Map<String, dynamic> json) {
    final petJson = json['pet'];
    final pet = petJson is Map<String, dynamic>
        ? AdoptionPetUiModel.fromApiJson(petJson)
        : AdoptionPetUiModel.fromApiJson(json);

    return AdoptionApplicationUiModel(
      id: _asInt(json['id']),
      status: _statusLabel(_asString(json['status'])),
      submittedAtLabel: _dateLabel(
        _asString(json['submittedAt']).isNotEmpty
            ? _asString(json['submittedAt'])
            : _asString(json['createdAt']),
      ),
      pet: pet,
    );
  }

  static String _statusLabel(String value) {
    if (value.isEmpty) return 'Submitted';
    return value
        .toLowerCase()
        .split('_')
        .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
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

  static int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
  static String _asString(dynamic value) => value?.toString().trim() ?? '';
}
