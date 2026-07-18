/// A feeling or activity item shown in the composer picker.
///
/// Can be created from the hardcoded list (fallback) or from the API.
/// When the API is available, items are fetched from the backend and
/// cached locally. The hardcoded list is used as a fallback if the API
/// is unreachable.
class FeelingActivityItem {
  final String id;
  final String label;
  final String emoji;
  final String category;
  final String type; // 'FEELING' or 'ACTIVITY'
  final bool isPetSpecific;

  const FeelingActivityItem({
    required this.id,
    required this.label,
    required this.emoji,
    required this.category,
    required this.type,
    this.isPetSpecific = false,
  });

  /// Creates from a backend API response.
  factory FeelingActivityItem.fromJson(Map<String, dynamic> json) {
    return FeelingActivityItem(
      id: json['id'].toString(),
      label: json['labelEn'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '',
      category: json['category'] as String? ?? '',
      type: json['type'] as String? ?? 'FEELING',
      isPetSpecific: json['isPetSpecific'] == true,
    );
  }

  /// Formatted string for display in the chip, e.g. "\u{1F60A} Happy"
  String get chipLabel => '$emoji $label';

  /// Full text appended to caption, e.g. "feeling Happy"
  String get captionTag => captionPrefix;

  /// Prefix used before the label: "feeling" or "activity"
  String get captionPrefix => type == 'feeling' ? 'feeling $label' : 'activity $label';

  // ── Presets ───────────────────────────────────────────────────────────

  static List<FeelingActivityItem> get all => [
        // ── Feelings ──
        ..._feelings,
        // ── Activities ──
        ..._activities,
        // ── Pet Care ──
        ..._petCare,
        // ── Health & Vet ──
        ..._healthVet,
        // ── Lost / Rescue / Adoption ──
        ..._lostRescue,
      ];

  static const List<FeelingActivityItem> _feelings = [
    FeelingActivityItem(id: 'happy', label: 'Happy', emoji: '\u{1F60A}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'sad', label: 'Sad', emoji: '\u{1F622}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'excited', label: 'Excited', emoji: '\u{1F929}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'blessed', label: 'Blessed', emoji: '\u{1F64F}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'loved', label: 'Loved', emoji: '\u{1F970}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'tired', label: 'Tired', emoji: '\u{1F634}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'proud', label: 'Proud', emoji: '\u{1F60E}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'angry', label: 'Angry', emoji: '\u{1F621}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'relaxed', label: 'Relaxed', emoji: '\u{1F60C}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'thankful', label: 'Thankful', emoji: '\u{1F917}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'hopeful', label: 'Hopeful', emoji: '\u{1F31F}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'emotional', label: 'Emotional', emoji: '\u{1F979}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'confused', label: 'Confused', emoji: '\u{1F615}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'worried', label: 'Worried', emoji: '\u{1F61F}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'sick', label: 'Sick', emoji: '\u{1F912}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'sleepy', label: 'Sleepy', emoji: '\u{1F62A}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'motivated', label: 'Motivated', emoji: '\u{1F4AA}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'grateful', label: 'Grateful', emoji: '\u{1F496}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'peaceful', label: 'Peaceful', emoji: '\u{1F54A}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'surprised', label: 'Surprised', emoji: '\u{1F62E}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'funny', label: 'Funny', emoji: '\u{1F604}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'cute', label: 'Cute', emoji: '\u{1F97A}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'cool', label: 'Cool', emoji: '\u{1F60E}', category: 'Feelings', type: 'feeling'),
    FeelingActivityItem(id: 'nervous', label: 'Nervous', emoji: '\u{1F62C}', category: 'Feelings', type: 'feeling'),
  ];

  static const List<FeelingActivityItem> _activities = [
    FeelingActivityItem(id: 'watching', label: 'Watching', emoji: '\u{1F3AC}', category: 'Activities', type: 'activity'),
    FeelingActivityItem(id: 'listening', label: 'Listening', emoji: '\u{1F3A7}', category: 'Activities', type: 'activity'),
    FeelingActivityItem(id: 'reading', label: 'Reading', emoji: '\u{1F4D6}', category: 'Activities', type: 'activity'),
    FeelingActivityItem(id: 'playing', label: 'Playing', emoji: '\u{1F3AE}', category: 'Activities', type: 'activity'),
    FeelingActivityItem(id: 'traveling', label: 'Traveling', emoji: '\u{2708}\u{FE0F}', category: 'Activities', type: 'activity'),
    FeelingActivityItem(id: 'eating', label: 'Eating', emoji: '\u{1F37D}', category: 'Activities', type: 'activity'),
    FeelingActivityItem(id: 'drinking', label: 'Drinking', emoji: '\u{2615}', category: 'Activities', type: 'activity'),
    FeelingActivityItem(id: 'celebrating', label: 'Celebrating', emoji: '\u{1F389}', category: 'Activities', type: 'activity'),
    FeelingActivityItem(id: 'working', label: 'Working', emoji: '\u{1F4BC}', category: 'Activities', type: 'activity'),
    FeelingActivityItem(id: 'shopping', label: 'Shopping', emoji: '\u{1F6CD}', category: 'Activities', type: 'activity'),
    FeelingActivityItem(id: 'cooking', label: 'Cooking', emoji: '\u{1F468}\u{200D}\u{1F373}', category: 'Activities', type: 'activity'),
    FeelingActivityItem(id: 'exercising', label: 'Exercising', emoji: '\u{1F3C3}', category: 'Activities', type: 'activity'),
    FeelingActivityItem(id: 'walking', label: 'Walking', emoji: '\u{1F6B6}', category: 'Activities', type: 'activity'),
    FeelingActivityItem(id: 'resting', label: 'Resting', emoji: '\u{1F6CC}', category: 'Activities', type: 'activity'),
  ];

  static const List<FeelingActivityItem> _petCare = [
    FeelingActivityItem(id: 'with_pet', label: 'With my pet', emoji: '\u{1F43E}', category: 'Pet Care', type: 'activity'),
    FeelingActivityItem(id: 'feeding_pet', label: 'Feeding my pet', emoji: '\u{1F37D}', category: 'Pet Care', type: 'activity'),
    FeelingActivityItem(id: 'grooming', label: 'Grooming my pet', emoji: '\u{1F9FC}', category: 'Pet Care', type: 'activity'),
    FeelingActivityItem(id: 'bathing', label: 'Bathing my pet', emoji: '\u{1F6C1}', category: 'Pet Care', type: 'activity'),
    FeelingActivityItem(id: 'walking_dog', label: 'Walking my dog', emoji: '\u{1F415}', category: 'Pet Care', type: 'activity'),
    FeelingActivityItem(id: 'playing_cat', label: 'Playing with cat', emoji: '\u{1F408}', category: 'Pet Care', type: 'activity'),
    FeelingActivityItem(id: 'training', label: 'Training my pet', emoji: '\u{1F393}', category: 'Pet Care', type: 'activity'),
    FeelingActivityItem(id: 'pet_shopping', label: 'Pet shopping', emoji: '\u{1F6CD}', category: 'Pet Care', type: 'activity'),
    FeelingActivityItem(id: 'pet_birthday', label: 'Pet birthday', emoji: '\u{1F382}', category: 'Pet Care', type: 'activity'),
    FeelingActivityItem(id: 'pet_photoshoot', label: 'Pet photo shoot', emoji: '\u{1F4F8}', category: 'Pet Care', type: 'activity'),
    FeelingActivityItem(id: 'pet_playtime', label: 'Pet playtime', emoji: '\u{1F9F8}', category: 'Pet Care', type: 'activity'),
    FeelingActivityItem(id: 'cleaning_litter', label: 'Cleaning litter box', emoji: '\u{1F9F9}', category: 'Pet Care', type: 'activity'),
    FeelingActivityItem(id: 'giving_treats', label: 'Giving treats', emoji: '\u{1F9B4}', category: 'Pet Care', type: 'activity'),
    FeelingActivityItem(id: 'cuddling', label: 'Cuddling my pet', emoji: '\u{1F917}', category: 'Pet Care', type: 'activity'),
    FeelingActivityItem(id: 'sleeping_pet', label: 'Sleeping with pet', emoji: '\u{1F634}', category: 'Pet Care', type: 'activity'),
  ];

  static const List<FeelingActivityItem> _healthVet = [
    FeelingActivityItem(id: 'vet_visit', label: 'Vet visit', emoji: '\u{1FA7A}', category: 'Health & Vet', type: 'activity'),
    FeelingActivityItem(id: 'pet_vaccination', label: 'Pet vaccination', emoji: '\u{1F489}', category: 'Health & Vet', type: 'activity'),
    FeelingActivityItem(id: 'deworming', label: 'Deworming', emoji: '\u{1F48A}', category: 'Health & Vet', type: 'activity'),
    FeelingActivityItem(id: 'pet_checkup', label: 'Pet checkup', emoji: '\u{1F3E5}', category: 'Health & Vet', type: 'activity'),
    FeelingActivityItem(id: 'pet_recovery', label: 'Pet recovery', emoji: '\u{2764}\u{FE0F}\u{200D}\u{1FA79}', category: 'Health & Vet', type: 'activity'),
    FeelingActivityItem(id: 'pet_medicine', label: 'Pet medicine', emoji: '\u{1F48A}', category: 'Health & Vet', type: 'activity'),
    FeelingActivityItem(id: 'emergency_care', label: 'Emergency care', emoji: '\u{1F691}', category: 'Health & Vet', type: 'activity'),
    FeelingActivityItem(id: 'surgery_care', label: 'Surgery care', emoji: '\u{1F3E5}', category: 'Health & Vet', type: 'activity'),
    FeelingActivityItem(id: 'dental_care', label: 'Dental care', emoji: '\u{1F9B7}', category: 'Health & Vet', type: 'activity'),
    FeelingActivityItem(id: 'health_concern', label: 'Health concern', emoji: '\u{26A0}\u{FE0F}', category: 'Health & Vet', type: 'activity'),
  ];

  static const List<FeelingActivityItem> _lostRescue = [
    FeelingActivityItem(id: 'searching_lost', label: 'Searching lost pet', emoji: '\u{1F50E}', category: 'Lost & Rescue', type: 'activity'),
    FeelingActivityItem(id: 'found_pet', label: 'Found a pet', emoji: '\u{1F43E}', category: 'Lost & Rescue', type: 'activity'),
    FeelingActivityItem(id: 'rescuing', label: 'Rescuing pet', emoji: '\u{1F6DF}', category: 'Lost & Rescue', type: 'activity'),
    FeelingActivityItem(id: 'adoption_day', label: 'Adoption day', emoji: '\u{1F3E1}', category: 'Lost & Rescue', type: 'activity'),
    FeelingActivityItem(id: 'looking_adopter', label: 'Looking for adopter', emoji: '\u{2764}\u{FE0F}', category: 'Lost & Rescue', type: 'activity'),
    FeelingActivityItem(id: 'foster_care', label: 'Foster care', emoji: '\u{1F3E0}', category: 'Lost & Rescue', type: 'activity'),
    FeelingActivityItem(id: 'reunited', label: 'Reunited with pet', emoji: '\u{1F91D}', category: 'Lost & Rescue', type: 'activity'),
    FeelingActivityItem(id: 'helping_stray', label: 'Helping stray animals', emoji: '\u{1F415}', category: 'Lost & Rescue', type: 'activity'),
    FeelingActivityItem(id: 'feeding_stray', label: 'Feeding stray animals', emoji: '\u{1F372}', category: 'Lost & Rescue', type: 'activity'),
    FeelingActivityItem(id: 'animal_welfare', label: 'Animal welfare', emoji: '\u{1F49A}', category: 'Lost & Rescue', type: 'activity'),
  ];

  /// Find an item by its [id]. Returns null if not found.
  static FeelingActivityItem? byId(String? id) {
    if (id == null) return null;
    return all.cast<FeelingActivityItem?>().firstWhere(
      (item) => item!.id == id,
      orElse: () => null,
    );
  }

  /// All category names in display order.
  static const List<String> categoryOrder = [
    'Feelings',
    'Activities',
    'Pet Care',
    'Health & Vet',
    'Lost & Rescue',
  ];

  /// Returns items for a given [category].
  static List<FeelingActivityItem> forCategory(String category) {
    return all.where((item) => item.category == category).toList();
  }
}
