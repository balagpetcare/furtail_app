import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:furtail_app/core/theme/furtail_design_tokens.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_draft_models.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

enum FundraisingChipVariant { neutral, success, warning, danger, info }

enum FundraisingInlineMessageVariant { neutral, success, warning, danger, info }

class FundraisingStepHeader extends StatelessWidget {
  const FundraisingStepHeader({
    super.key,
    required this.stepLabel,
    required this.title,
    this.subtitle,
    this.progress,
  });

  final String stepLabel;
  final String title;
  final String? subtitle;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  stepLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const Spacer(),
              if (progress != null)
                Text(
                  '${(progress!.clamp(0, 1) * 100).round()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress!.clamp(0, 1),
                minHeight: 5,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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

  static const List<FundraisingWizardStep> _visibleSteps =
      <FundraisingWizardStep>[
        FundraisingWizardStep.fundraiserType,
        FundraisingWizardStep.storyAndGoal,
        FundraisingWizardStep.caseDetails,
        FundraisingWizardStep.location,
        FundraisingWizardStep.evidence,
        FundraisingWizardStep.preview,
      ];

  static int get totalSteps => _visibleSteps.length;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final stepIndex = _visibleSteps
        .indexOf(currentStep)
        .clamp(0, totalSteps - 1);
    final progress = (stepIndex + 1) / totalSteps;
    return FundraisingStepHeader(
      stepLabel: t.fundraisingWizardStepOf(stepIndex + 1, totalSteps),
      title: _stepTitle(t, currentStep),
      subtitle: _stepSubtitle(t, currentStep),
      progress: progress,
    );
  }

  static String _stepTitle(AppLocalizations t, FundraisingWizardStep step) {
    switch (step) {
      case FundraisingWizardStep.fundraiserType:
        return 'Campaign Basics';
      case FundraisingWizardStep.storyAndGoal:
        return 'Campaign Story';
      case FundraisingWizardStep.caseDetails:
        return 'Funding Details';
      case FundraisingWizardStep.location:
        return 'Location';
      case FundraisingWizardStep.evidence:
        return 'Media & Documents';
      case FundraisingWizardStep.preview:
        return 'Review & Submit';
      default:
        return t.fundraisingWizardStepDetails;
    }
  }

  static String _stepSubtitle(AppLocalizations t, FundraisingWizardStep step) {
    switch (step) {
      case FundraisingWizardStep.fundraiserType:
        return t.fundraisingWizardBeneficiaryDescription;
      case FundraisingWizardStep.storyAndGoal:
        return t.fundraisingWizardStoryDescription;
      case FundraisingWizardStep.caseDetails:
        return t.fundraisingWizardCaseDescription;
      case FundraisingWizardStep.location:
        return t.fundraisingWizardLocationDescription;
      case FundraisingWizardStep.evidence:
        return t.fundraisingWizardEvidenceDescription;
      case FundraisingWizardStep.preview:
        return t.fundraisingWizardPreviewDescription;
      default:
        return '';
    }
  }
}

class FundraisingSectionCard extends StatelessWidget {
  const FundraisingSectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || subtitle != null || trailing != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null) ...[
                        Text(
                          title!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ],
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

InputDecoration _fundraisingDecoration(
  BuildContext context, {
  required String labelText,
  String? hintText,
  String? helperText,
  String? prefixText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool multiline = false,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final radius = BorderRadius.circular(12);
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    prefixText: prefixText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: scheme.surfaceContainerLowest,
    isDense: true,
    alignLabelWithHint: multiline,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    labelStyle: theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontSize: 14,
    ),
    floatingLabelStyle: theme.textTheme.labelMedium?.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.w700,
    ),
    hintStyle: theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
      fontSize: 14,
    ),
    helperStyle: theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.35,
    ),
    errorStyle: theme.textTheme.bodySmall?.copyWith(
      color: scheme.error,
      height: 1.3,
    ),
    helperMaxLines: 3,
    errorMaxLines: 3,
    contentPadding: EdgeInsets.symmetric(
      horizontal: 14,
      vertical: multiline ? 14 : 13,
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
    suffixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: 0.88),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.primary, width: 1.8),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.error, width: 1.4),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.error, width: 1.8),
    ),
  );
}

class FundraisingTextField extends StatelessWidget {
  const FundraisingTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.helperText,
    this.prefixText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.validator,
    this.onTap,
    this.readOnly = false,
    this.enabled,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? helperText;
  final String? prefixText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool? enabled;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final multiline = maxLines > 1;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: multiline ? 0 : 52),
      child: TextFormField(
        controller: controller,
        decoration: _fundraisingDecoration(
          context,
          labelText: labelText,
          hintText: hintText,
          helperText: helperText,
          prefixText: prefixText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          multiline: multiline,
        ),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          height: multiline ? 1.42 : 1.25,
        ),
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        validator: validator,
        onTap: onTap,
        readOnly: readOnly,
        enabled: enabled,
        minLines: minLines,
        maxLines: maxLines,
        maxLength: maxLength,
        textAlignVertical: multiline
            ? TextAlignVertical.top
            : TextAlignVertical.center,
        scrollPadding: const EdgeInsets.fromLTRB(20, 80, 20, 190),
        inputFormatters: inputFormatters,
        autofillHints: autofillHints,
      ),
    );
  }
}

class FundraisingDropdownField<T> extends StatelessWidget {
  const FundraisingDropdownField({
    super.key,
    required this.labelText,
    required this.items,
    required this.onChanged,
    this.value,
    this.hintText,
    this.helperText,
    this.enabled = true,
  });

  final String labelText;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final String? hintText;
  final String? helperText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        menuMaxHeight: 340,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontSize: 15,
        ),
        items: items,
        onChanged: enabled ? onChanged : null,
        decoration: _fundraisingDecoration(
          context,
          labelText: labelText,
          hintText: hintText,
          helperText: helperText,
        ),
      ),
    );
  }
}

class FundraisingAmountField extends StatelessWidget {
  const FundraisingAmountField({
    super.key,
    required this.controller,
    required this.labelText,
    this.prefixText = 'BDT ',
    this.hintText,
    this.helperText,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.enabled,
  });

  final TextEditingController controller;
  final String labelText;
  final String prefixText;
  final String? hintText;
  final String? helperText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    return FundraisingTextField(
      controller: controller,
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      prefixText: prefixText,
      keyboardType: keyboardType ?? TextInputType.number,
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
      validator: validator,
      enabled: enabled,
    );
  }
}

class FundraisingStatusChip extends StatelessWidget {
  const FundraisingStatusChip({
    super.key,
    required this.label,
    this.variant = FundraisingChipVariant.neutral,
    this.icon,
  });

  final String label;
  final FundraisingChipVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (variant) {
      FundraisingChipVariant.success => (
        FurtailDesignTokens.success.withValues(alpha: 0.12),
        FurtailDesignTokens.success,
      ),
      FundraisingChipVariant.warning => (
        FurtailDesignTokens.warning.withValues(alpha: 0.12),
        FurtailDesignTokens.warning,
      ),
      FundraisingChipVariant.danger => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      FundraisingChipVariant.info => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      FundraisingChipVariant.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FundraisingInlineMessage extends StatelessWidget {
  const FundraisingInlineMessage({
    super.key,
    required this.message,
    this.title,
    this.variant = FundraisingInlineMessageVariant.neutral,
    this.icon,
  });

  final String? title;
  final String message;
  final FundraisingInlineMessageVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground, effectiveIcon) = switch (variant) {
      FundraisingInlineMessageVariant.success => (
        FurtailDesignTokens.success.withValues(alpha: 0.10),
        FurtailDesignTokens.success,
        icon ?? Icons.check_circle_outline_rounded,
      ),
      FundraisingInlineMessageVariant.warning => (
        FurtailDesignTokens.warning.withValues(alpha: 0.12),
        FurtailDesignTokens.warning,
        icon ?? Icons.warning_amber_rounded,
      ),
      FundraisingInlineMessageVariant.danger => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        icon ?? Icons.error_outline_rounded,
      ),
      FundraisingInlineMessageVariant.info => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        icon ?? Icons.info_outline_rounded,
      ),
      FundraisingInlineMessageVariant.neutral => (
        scheme.surfaceContainerLow,
        scheme.onSurfaceVariant,
        icon ?? Icons.info_outline_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: foreground.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(effectiveIcon, size: 18, color: foreground),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.trim().isNotEmpty) ...[
                  Text(
                    title!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foreground,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FundraisingWizardBottomBar extends StatelessWidget {
  const FundraisingWizardBottomBar({
    super.key,
    required this.canGoBack,
    required this.onBack,
    required this.onCancel,
    required this.onSaveDraft,
    required this.onContinue,
    required this.continueLabel,
    this.busy = false,
    bool? disabled,
    this.showSaveDraft = true,
    this.continueEnabled = true,
    this.helperText,
  }) : disabled = disabled ?? busy;

  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final VoidCallback onSaveDraft;
  final VoidCallback onContinue;
  final String continueLabel;
  final bool busy;
  final bool disabled;
  final bool showSaveDraft;
  final bool continueEnabled;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showHelper = !continueEnabled && (helperText ?? '').trim().isNotEmpty;

    Widget secondaryButton(
      String label,
      VoidCallback? onPressed, {
      bool textOnly = false,
    }) {
      final child = Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      );
      return SizedBox(
        height: 44,
        child: textOnly
            ? TextButton(onPressed: disabled ? null : onPressed, child: child)
            : OutlinedButton(
                onPressed: disabled ? null : onPressed,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: child,
              ),
      );
    }

    Widget primaryButton() {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: (disabled || !continueEnabled) ? null : onContinue,
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  continueLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      );
    }

    final secondaryLabel = canGoBack ? t.fundraisingBack : t.fundraisingCancel;
    final secondaryAction = canGoBack ? onBack : onCancel;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHelper) ...[
              FundraisingInlineMessage(
                variant: FundraisingInlineMessageVariant.info,
                message: helperText!,
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: 8),
            ],
            primaryButton(),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: secondaryButton(
                    secondaryLabel,
                    secondaryAction,
                    textOnly: true,
                  ),
                ),
                if (showSaveDraft) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: secondaryButton(
                      t.fundraisingSaveDraft,
                      onSaveDraft,
                      textOnly: true,
                    ),
                  ),
                ],
              ],
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
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
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
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
    return Column(
      children: [
        for (final message in messages) ...[
          FundraisingInlineMessage(
            variant: FundraisingInlineMessageVariant.danger,
            message: message,
            icon: Icons.error_outline_rounded,
          ),
          if (message != messages.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}
