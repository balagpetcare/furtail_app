import 'package:flutter/material.dart';

/// Describes the standard Save action for a settings screen: disabled
/// while saving and disabled until the form is dirty.
class SettingsSaveState {
  const SettingsSaveState({required this.saving, required this.dirty, required this.onSave});

  final bool saving;
  final bool dirty;
  final VoidCallback onSave;
}

/// Shared scaffold for every Profile Settings screen: consistent app bar
/// with a visible title and back button, one Save pattern (disabled until
/// dirty and while saving), a discard-changes prompt on pop when there are
/// unsaved edits, consistent content padding, keyboard-safe scrolling, and
/// SafeArea. Works for both light and dark themes via ColorScheme tokens
/// only — no hard-coded colors.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.body,
    this.saveState,
    this.hasUnsavedChanges = false,
    this.bottom,
    this.scrollable = true,
    this.actions,
  });

  /// Page title — always visible in the app bar.
  final String title;

  /// Main content. When [scrollable] is true (the default), this is
  /// wrapped in SafeArea + keyboard-dismissing SingleChildScrollView with
  /// standard 16px padding. Screens that manage their own scrolling (e.g.
  /// a TabBarView) should pass `scrollable: false`.
  final Widget body;

  /// Non-null enables the standard app-bar Save button, disabled while
  /// [SettingsSaveState.saving] or until [SettingsSaveState.dirty].
  final SettingsSaveState? saveState;

  /// When true, popping while dirty shows a "Discard changes?" prompt.
  final bool hasUnsavedChanges;

  /// Optional app-bar bottom widget (e.g. Safety's TabBar).
  final PreferredSizeWidget? bottom;

  /// False for screens that manage their own scroll/layout (e.g. TabBarView).
  final bool scrollable;

  /// Extra app-bar actions shown before the Save button, if any.
  final List<Widget>? actions;

  Future<bool> _confirmDiscard(BuildContext context) async {
    final colors = Theme.of(context).colorScheme;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('Are you sure you want to discard your changes?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Editing')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final save = saveState;
    Widget content = body;
    if (scrollable) {
      content = SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          child: body,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: bottom,
        actions: [
          ...?actions,
          if (save != null)
            TextButton(
              onPressed: (save.saving || !save.dirty) ? null : save.onSave,
              child: save.saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: hasUnsavedChanges
          ? PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                if (save?.saving ?? false) return;
                if (await _confirmDiscard(context) && context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: content,
            )
          : content,
    );
  }
}

/// Standard section-heading label used throughout Profile Settings forms.
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Standard inline error banner used throughout Profile Settings screens —
/// always errorContainer/onErrorContainer, never a hard-coded red.
class SettingsErrorBanner extends StatelessWidget {
  const SettingsErrorBanner({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: colors.onErrorContainer),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}
