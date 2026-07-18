import 'package:flutter/material.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_application_ui_model.dart';

enum FitLabel { bestMatch, goodMatch, needsReview, lowFit }

class FitBreakdownItem {
  final String label;
  final String description;
  final FitItemState state;
  final int points;

  const FitBreakdownItem({
    required this.label,
    required this.description,
    required this.state,
    required this.points,
  });
}

enum FitItemState { good, warning, bad, neutral }

class AdoptionFitScore {
  final int score;
  final FitLabel label;
  final List<FitBreakdownItem> breakdown;
  final List<String> tags;

  const AdoptionFitScore({
    required this.score,
    required this.label,
    required this.breakdown,
    required this.tags,
  });

  static AdoptionFitScore compute(AdoptionApplicationUiModel app) {
    final items = <FitBreakdownItem>[];
    final tags = <String>[];
    int total = 0;
    int max = 0;

    // --- Contact verification (20 pts) ---
    max += 20;
    final hasPhone = app.applicantPhone.isNotEmpty;
    final hasWhatsapp = app.applicantWhatsappPhone.isNotEmpty;
    if (hasPhone && hasWhatsapp) {
      total += 20;
      tags.add('Verified Phone');
      items.add(const FitBreakdownItem(
        label: 'Contact Availability',
        description: 'Phone and WhatsApp provided',
        state: FitItemState.good,
        points: 20,
      ));
    } else if (hasPhone || hasWhatsapp) {
      total += 12;
      items.add(const FitBreakdownItem(
        label: 'Contact Availability',
        description: 'Partial contact info provided',
        state: FitItemState.warning,
        points: 12,
      ));
    } else {
      tags.add('Incomplete');
      items.add(const FitBreakdownItem(
        label: 'Contact Availability',
        description: 'No contact number provided',
        state: FitItemState.bad,
        points: 0,
      ));
    }

    // --- Location (15 pts) ---
    max += 15;
    final hasLocation = app.applicantCityAreaText.isNotEmpty || app.applicantAddress.isNotEmpty;
    if (hasLocation) {
      total += 15;
      tags.add('Nearby');
      items.add(FitBreakdownItem(
        label: 'Location',
        description: app.applicantCityAreaText.isNotEmpty
            ? app.applicantCityAreaText
            : 'Location provided',
        state: FitItemState.good,
        points: 15,
      ));
    } else {
      items.add(const FitBreakdownItem(
        label: 'Location',
        description: 'No location information',
        state: FitItemState.warning,
        points: 0,
      ));
    }

    // --- Pet experience (20 pts) ---
    max += 20;
    final expText = app.applicantExperienceSummary.toLowerCase();
    final hasPriorExp = expText.contains('year') ||
        expText.contains('owned') ||
        expText.contains('had') ||
        expText.contains('raised') ||
        expText.contains('rescue');
    final hasExpField = app.applicantExperienceSummary.isNotEmpty;
    if (hasPriorExp) {
      total += 20;
      tags.add('Experienced');
      items.add(FitBreakdownItem(
        label: 'Pet Experience',
        description: app.applicantExperienceSummary.length > 60
            ? '${app.applicantExperienceSummary.substring(0, 60)}…'
            : app.applicantExperienceSummary,
        state: FitItemState.good,
        points: 20,
      ));
    } else if (hasExpField) {
      total += 10;
      items.add(FitBreakdownItem(
        label: 'Pet Experience',
        description: app.applicantExperienceSummary.length > 60
            ? '${app.applicantExperienceSummary.substring(0, 60)}…'
            : app.applicantExperienceSummary,
        state: FitItemState.warning,
        points: 10,
      ));
    } else {
      items.add(const FitBreakdownItem(
        label: 'Pet Experience',
        description: 'No experience information provided',
        state: FitItemState.warning,
        points: 0,
      ));
    }

    // --- Housing safety (15 pts) ---
    max += 15;
    final houseSafe = app.applicantHouseholdSummary.isNotEmpty;
    final consentHome = app.consentToHomeCheck;
    if (houseSafe && consentHome) {
      total += 15;
      items.add(const FitBreakdownItem(
        label: 'Housing Safety',
        description: 'Household described, home check consented',
        state: FitItemState.good,
        points: 15,
      ));
    } else if (houseSafe || consentHome) {
      total += 8;
      items.add(FitBreakdownItem(
        label: 'Housing Safety',
        description: consentHome
            ? 'Home check consented; household not described'
            : 'Household described; no home check consent',
        state: FitItemState.warning,
        points: 8,
      ));
    } else {
      tags.add('Needs Safety Check');
      items.add(const FitBreakdownItem(
        label: 'Housing Safety',
        description: 'No household or home check information',
        state: FitItemState.bad,
        points: 0,
      ));
    }

    // --- Owner conditions accepted (10 pts) ---
    max += 10;
    if (app.consentToFollowUp) {
      total += 10;
      items.add(const FitBreakdownItem(
        label: 'Owner Conditions',
        description: 'Follow-up visits accepted',
        state: FitItemState.good,
        points: 10,
      ));
    } else {
      items.add(const FitBreakdownItem(
        label: 'Owner Conditions',
        description: 'Follow-up not consented',
        state: FitItemState.warning,
        points: 0,
      ));
    }

    // --- Answer completeness (20 pts) ---
    max += 20;
    final answerCount = app.answers.length;
    final answeredCount = app.answers
        .where((a) => (a['answerText']?.toString().trim() ?? '').isNotEmpty)
        .length;
    if (answerCount == 0) {
      items.add(const FitBreakdownItem(
        label: 'Answer Completeness',
        description: 'No questionnaire answers',
        state: FitItemState.neutral,
        points: 0,
      ));
    } else {
      final ratio = answeredCount / answerCount;
      final pts = (ratio * 20).round();
      total += pts;
      items.add(FitBreakdownItem(
        label: 'Answer Completeness',
        description: '$answeredCount / $answerCount questions answered',
        state: ratio >= 0.8
            ? FitItemState.good
            : ratio >= 0.5
                ? FitItemState.warning
                : FitItemState.bad,
        points: pts,
      ));
      if (ratio < 0.5) tags.add('Incomplete');
    }

    final score = max == 0 ? 0 : ((total / max) * 100).round().clamp(0, 100);

    final label = score >= 85
        ? FitLabel.bestMatch
        : score >= 65
            ? FitLabel.goodMatch
            : score >= 45
                ? FitLabel.needsReview
                : FitLabel.lowFit;

    return AdoptionFitScore(
      score: score,
      label: label,
      breakdown: items,
      tags: tags,
    );
  }

  String get labelText => switch (label) {
        FitLabel.bestMatch => 'Best Match',
        FitLabel.goodMatch => 'Good Match',
        FitLabel.needsReview => 'Needs Review',
        FitLabel.lowFit => 'Low Fit',
      };

  Color labelColor(BuildContext context) => switch (label) {
        FitLabel.bestMatch => Colors.green.shade700,
        FitLabel.goodMatch => Colors.blue.shade700,
        FitLabel.needsReview => Colors.orange.shade700,
        FitLabel.lowFit => Colors.red.shade700,
      };

  Color labelBg(BuildContext context) => switch (label) {
        FitLabel.bestMatch => Colors.green.shade50,
        FitLabel.goodMatch => Colors.blue.shade50,
        FitLabel.needsReview => Colors.orange.shade50,
        FitLabel.lowFit => Colors.red.shade50,
      };

  String get scoreText => '$score%';
}
