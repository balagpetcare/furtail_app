class AdoptionApplicationFormPayload {
  final String applicantLocationText;
  final String housingType;
  final bool familyApproval;
  final String previousPetExperience;
  final String currentPetsNote;
  final String incomeRange;
  final bool canProvideVetCare;
  final String adoptionReason;
  final String ownerConditionAnswers;
  final bool acceptsTerms;

  const AdoptionApplicationFormPayload({
    required this.applicantLocationText,
    required this.housingType,
    required this.familyApproval,
    required this.previousPetExperience,
    required this.currentPetsNote,
    required this.incomeRange,
    required this.canProvideVetCare,
    required this.adoptionReason,
    required this.ownerConditionAnswers,
    required this.acceptsTerms,
  });

  Map<String, dynamic> toApiPayload() {
    final answers = <Map<String, dynamic>>[];
    if (_trim(housingType).isNotEmpty) {
      answers.add({
        'questionKey': 'housing_type',
        'questionLabel': 'Housing type',
        'answerText': _trim(housingType),
      });
    }
    if (_trim(ownerConditionAnswers).isNotEmpty) {
      answers.add({
        'questionKey': 'owner_conditions',
        'questionLabel': 'Owner conditions response',
        'answerText': _trim(ownerConditionAnswers),
      });
    }

    return {
      'messageToOwner': _trim(adoptionReason),
      if (_trim(applicantLocationText).isNotEmpty)
        'applicantAddress': _trim(applicantLocationText),
      if (_trim(housingType).isNotEmpty)
        'applicantHouseholdSummary':
            'Housing type: ${_trim(housingType)}. Family approval: ${familyApproval ? 'Yes' : 'No'}.',
      if (_trim(previousPetExperience).isNotEmpty)
        'applicantExperienceSummary': _trim(previousPetExperience),
      if (_trim(currentPetsNote).isNotEmpty)
        'applicantOtherPetsSummary': _trim(currentPetsNote),
      if (_trim(incomeRange).isNotEmpty)
        'applicantIncomeRange': _trim(incomeRange),
      'consentToHomeCheck': acceptsTerms,
      'consentToFollowUp': canProvideVetCare,
      if (answers.isNotEmpty) 'answers': answers,
    };
  }

  static String _trim(String value) => value.trim();
}
