import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';

const _reasons = [
  ('FAKE_LISTING', 'Fake or misleading listing'),
  ('PET_SELLING', 'Selling pets (against policy)'),
  ('SCAM', 'Scam or fraud attempt'),
  ('WRONG_INFO', 'Wrong or inaccurate information'),
  ('DUPLICATE', 'Duplicate listing'),
  ('SICK_PET_HIDDEN', 'Sick pet — health info hidden'),
  ('ABUSE_CONCERN', 'Animal abuse concern'),
  ('SUSPICIOUS_PAYMENT', 'Suspicious payment request'),
  ('OTHER', 'Other'),
];

class AdoptionReportSheet extends StatefulWidget {
  final Future<void> Function(String reasonCode, String? details) onSubmit;

  const AdoptionReportSheet({super.key, required this.onSubmit});

  @override
  State<AdoptionReportSheet> createState() => _AdoptionReportSheetState();
}

class _AdoptionReportSheetState extends State<AdoptionReportSheet> {
  String? _selectedReason;
  final _detailsCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      setState(() => _error = 'Please select a reason.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        _selectedReason!,
        _detailsCtrl.text.trim().isEmpty ? null : _detailsCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxxl),
              children: [
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Report this listing',
                  style: AppTypography.sectionTitle(context).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Our team reviews all reports and takes appropriate action.',
                  style: AppTypography.caption(context).copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.lg),
                ..._reasons.map(((String code, String label) r) {
                  return RadioListTile<String>(
                    value: r.$1,
                    groupValue: _selectedReason,
                    onChanged: (v) => setState(() {
                      _selectedReason = v;
                      _error = null;
                    }),
                    title: Text(r.$2, style: AppTypography.bodyRegular(context)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _detailsCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Additional details (optional)',
                    hintText: 'Describe the issue...',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: TextStyle(color: cs.error, fontSize: 12)),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit Report'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
