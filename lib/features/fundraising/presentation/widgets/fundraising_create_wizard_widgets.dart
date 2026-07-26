import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:furtail_app/core/theme/furtail_design_tokens.dart';
import 'package:furtail_app/core/theme/spacing.dart';
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stepLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: FurtailDesignTokens.textSecondary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.visible,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: FurtailDesignTokens.textSecondary(context),
              ),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress!.clamp(0, 1),
                minHeight: 6,
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
        FundraisingWizardStep.location,
        FundraisingWizardStep.preview,
      ];

  static int get totalSteps => _visibleSteps.length;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final stepIndex = _visibleSteps.indexOf(currentStep);
    final progress = (stepIndex + 1) / totalSteps;
    return FundraisingStepHeader(
      stepLabel: t.fundraisingWizardStepOf(stepIndex + 1, totalSteps),
      title: _stepTitle(t, currentStep),
      progress: progress,
    );
  }

  static String _stepTitle(AppLocalizations t, FundraisingWizardStep step) {
    switch (step) {
      case FundraisingWizardStep.fundraiserType:
        return t.fundraisingWizardStepDetails;
      case FundraisingWizardStep.location:
        return t.fundraisingWizardStepMediaLocation;
      case FundraisingWizardStep.preview:
        return t.fundraisingWizardStepPreview;
      default:
        return t.fundraisingWizardStepDetails;
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.65),
        ),
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: FurtailDesignTokens.textSecondary(
                                  context,
                                ),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
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
  final scheme = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    prefixText: prefixText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: scheme.surfaceContainerLow,
    isDense: true,
    alignLabelWithHint: multiline,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    contentPadding: EdgeInsets.symmetric(
      horizontal: 16,
      vertical: multiline ? 16 : 18,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: scheme.primary, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: scheme.error, width: 1.4),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: scheme.error, width: 1.6),
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
    this.inputFormatters,
    this.autofillHints,
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
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final multiline = maxLines > 1;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: multiline ? 0 : 56),
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
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onChanged: onChanged,
        validator: validator,
        onTap: onTap,
        readOnly: readOnly,
        enabled: enabled,
        minLines: minLines,
        maxLines: maxLines,
        textAlignVertical: multiline
            ? TextAlignVertical.top
            : TextAlignVertical.center,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
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
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, effectiveIcon) = switch (variant) {
      FundraisingInlineMessageVariant.success => (
        FurtailDesignTokens.success.withValues(alpha: 0.10),
        FurtailDesignTokens.success,
        icon ?? Icons.check_circle_outline_rounded,
      ),
      FundraisingInlineMessageVariant.warning => (
        FurtailDesignTokens.warning.withValues(alpha: 0.14),
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
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        icon ?? Icons.info_outline_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(effectiveIcon, size: 18, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.trim().isNotEmpty) ...[
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: foreground),
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
    this.showSaveDraft = true,
    this.continueEnabled = true,
    this.helperText,
  });

  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final VoidCallback onSaveDraft;
  final VoidCallback onContinue;
  final String continueLabel;
  final bool busy;
  final bool showSaveDraft;
  final bool continueEnabled;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final showHelper = !continueEnabled && (helperText ?? '').trim().isNotEmpty;

    Widget secondaryButton(String label, VoidCallback? onPressed) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: busy ? null : onPressed,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ),
      );
    }

    Widget primaryButton({required double? width}) {
      final button = SizedBox(
        height: 56,
        width: width,
        child: FilledButton(
          onPressed: (busy || !continueEnabled) ? null : onContinue,
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    continueLabel,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
        ),
      );
      return button;
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 380;

            final secondaryLabel = canGoBack
                ? t.fundraisingBack
                : t.fundraisingCancel;
            final secondaryAction = canGoBack ? onBack : onCancel;

            final secondaryRow = showSaveDraft
                ? Row(
                    children: [
                      Expanded(
                        child: secondaryButton(secondaryLabel, secondaryAction),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: secondaryButton(
                          t.fundraisingSaveDraft,
                          onSaveDraft,
                        ),
                      ),
                    ],
                  )
                : secondaryButton(secondaryLabel, secondaryAction);

            if (narrow) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showHelper) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FundraisingInlineMessage(
                        variant: FundraisingInlineMessageVariant.info,
                        message: helperText!,
                        icon: Icons.info_outline_rounded,
                      ),
                    ),
                  ],
                  secondaryRow,
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: primaryButton(width: null),
                  ),
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showHelper) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FundraisingInlineMessage(
                      variant: FundraisingInlineMessageVariant.info,
                      message: helperText!,
                      icon: Icons.info_outline_rounded,
                    ),
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: secondaryButton(secondaryLabel, secondaryAction),
                    ),
                    if (showSaveDraft) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: secondaryButton(
                          t.fundraisingSaveDraft,
                          onSaveDraft,
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),
                    Expanded(child: primaryButton(width: null)),
                  ],
                ),
              ],
            );
          },
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
    return FundraisingSectionCard(
      title: title,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(body, style: Theme.of(context).textTheme.bodyMedium),
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
