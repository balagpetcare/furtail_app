import 'package:flutter/material.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_draft_models.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

class FundraisingWizardProgressHeader extends StatelessWidget {
  const FundraisingWizardProgressHeader({
    super.key,
    required this.currentStep,
    required this.completedSteps,
    required this.onStepTapped,
  });

  final FundraisingWizardStep currentStep;
  final Set<FundraisingWizardStep> completedSteps;
  final ValueChanged<FundraisingWizardStep> onStepTapped;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 108,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: FundraisingWizardStep.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final step = FundraisingWizardStep.values[index];
          final isCurrent = step == currentStep;
          final isCompleted = completedSteps.contains(step);
          final background = isCurrent
              ? colorScheme.primary
              : isCompleted
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest;
          final foreground = isCurrent
              ? colorScheme.onPrimary
              : isCompleted
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant;
          return Semantics(
            button: true,
            selected: isCurrent,
            label: '${index + 1}. ${_stepTitle(t, step)}',
            child: InkWell(
              onTap: () => onStepTapped(step),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 116,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: foreground.withValues(alpha: 0.14),
                      child: Icon(
                        isCompleted ? Icons.check_rounded : Icons.circle,
                        size: isCompleted ? 16 : 10,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${index + 1}. ${_stepTitle(t, step)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _stepTitle(AppLocalizations t, FundraisingWizardStep step) {
    switch (step) {
      case FundraisingWizardStep.eligibility:
        return t.fundraisingWizardStepEligibility;
      case FundraisingWizardStep.fundraiserType:
        return t.fundraisingWizardStepBeneficiary;
      case FundraisingWizardStep.storyAndGoal:
        return t.fundraisingWizardStepStory;
      case FundraisingWizardStep.caseDetails:
        return t.fundraisingWizardStepCase;
      case FundraisingWizardStep.location:
        return t.fundraisingWizardStepLocation;
      case FundraisingWizardStep.evidence:
        return t.fundraisingWizardStepEvidence;
      case FundraisingWizardStep.payoutReadiness:
        return t.fundraisingWizardStepPayout;
      case FundraisingWizardStep.preview:
        return t.fundraisingWizardStepPreview;
    }
  }
}

class FundraisingWizardBottomBar extends StatelessWidget {
  const FundraisingWizardBottomBar({
    super.key,
    required this.canGoBack,
    required this.onBack,
    required this.onSaveDraft,
    required this.onContinue,
    required this.continueLabel,
    this.busy = false,
  });

  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onSaveDraft;
  final VoidCallback onContinue;
  final String continueLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: busy ? null : (canGoBack ? onBack : null),
                  child: Text(AppLocalizations.of(context)!.fundraisingBack),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: busy ? null : onSaveDraft,
                  child: Text(
                    AppLocalizations.of(context)!.fundraisingSaveDraft,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: busy ? null : onContinue,
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(continueLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FundraisingInfoCard extends StatelessWidget {
  const FundraisingInfoCard({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
  });

  final String title;
  final String body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class FundraisingValidationBanner extends StatelessWidget {
  const FundraisingValidationBanner({super.key, required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: messages
            .map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $message',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
