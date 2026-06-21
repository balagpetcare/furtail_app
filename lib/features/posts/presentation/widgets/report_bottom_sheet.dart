import 'package:flutter/material.dart';

import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/core/theme/typography.dart';
import '../../../../core/services/report_service.dart';

enum ReportTargetType { post, fundraising, user, pet }

extension _ReportTargetTypeX on ReportTargetType {
  String get apiType {
    switch (this) {
      case ReportTargetType.post:
        return 'POST';
      case ReportTargetType.fundraising:
        return 'FUNDRAISING';
      case ReportTargetType.user:
        return 'USER';
      case ReportTargetType.pet:
        return 'PET';
    }
  }

  String get title {
    switch (this) {
      case ReportTargetType.post:
        return 'Report post';
      case ReportTargetType.fundraising:
        return 'Report fundraising';
      case ReportTargetType.user:
        return 'Report user';
      case ReportTargetType.pet:
        return 'Report pet profile';
    }
  }
}

typedef ReportSubmitter = Future<void> Function(
  ReportTargetType type,
  int targetId,
  String reasonCode, {
  String? details,
});

/// A clean, reusable report bottom sheet.
///
/// Backend integration is optional: pass [onSubmit] to send a report.
/// If [onSubmit] is null, it will behave as a dummy flow.
class ReportBottomSheet extends StatefulWidget {
  final ReportTargetType targetType;
  final int targetId;
  final ReportSubmitter? onSubmit;

  const ReportBottomSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    required ReportTargetType targetType,
    required int targetId,
    ReportSubmitter? onSubmit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ReportBottomSheet(
          targetType: targetType,
          targetId: targetId,
          onSubmit: onSubmit,
        ),
      ),
    );
  }

  /// Backwards compatible helper for older code: reports a post.
  static Future<void> showPost(
    BuildContext context, {
    required int postId,
    ReportSubmitter? onSubmit,
  }) {
    return show(context, targetType: ReportTargetType.post, targetId: postId, onSubmit: onSubmit);
  }

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  static const Map<ReportTargetType, List<Map<String, String>>> _reasonCatalog = {
    ReportTargetType.post: [
      {'code': 'SPAM', 'label': 'Spam'},
      {'code': 'INAPPROPRIATE', 'label': 'Inappropriate content'},
      {'code': 'ANIMAL_ABUSE', 'label': 'Animal abuse'},
      {'code': 'FALSE_INFO', 'label': 'False or misleading information'},
      {'code': 'HARASSMENT', 'label': 'Harassment or hate'},
      {'code': 'OTHER', 'label': 'Other'},
    ],
    ReportTargetType.fundraising: [
      {'code': 'FRAUD', 'label': 'Fraud / scam'},
      {'code': 'MISLEADING', 'label': 'Misleading fundraising details'},
      {'code': 'DUPLICATE', 'label': 'Duplicate campaign'},
      {'code': 'IMPROPER_USE', 'label': 'Suspicious use of funds'},
      {'code': 'INAPPROPRIATE', 'label': 'Inappropriate content'},
      {'code': 'OTHER', 'label': 'Other'},
    ],
    ReportTargetType.user: [
      {'code': 'IMPERSONATION', 'label': 'Impersonation'},
      {'code': 'HARASSMENT', 'label': 'Harassment or hate'},
      {'code': 'SPAM', 'label': 'Spam'},
      {'code': 'SCAM', 'label': 'Scam or suspicious behavior'},
      {'code': 'OTHER', 'label': 'Other'},
    ],
    ReportTargetType.pet: [
      {'code': 'FAKE_PROFILE', 'label': 'Fake pet profile'},
      {'code': 'WRONG_INFO', 'label': 'Wrong or misleading information'},
      {'code': 'ABUSE', 'label': 'Animal abuse / cruelty'},
      {'code': 'SPAM', 'label': 'Spam'},
      {'code': 'OTHER', 'label': 'Other'},
    ],
  };

  String? _selectedCode;
  final _details = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedCode == null) return;
    setState(() => _submitting = true);
    try {
      final details = _details.text.trim().isEmpty ? null : _details.text.trim();
      if (widget.onSubmit != null) {
        await widget.onSubmit!(widget.targetType, widget.targetId, _selectedCode!, details: details);
      } else {
        await ReportService.submit(
          type: widget.targetType.apiType,
          targetId: widget.targetId,
          reasonCode: _selectedCode!,
          details: details,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for helping keep BPA safe 🐾')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Report failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E6E6),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.targetType.title,
              style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Help us understand what\'s wrong.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ...(_reasonCatalog[widget.targetType] ?? const [])
                .map((item) {
              final code = item['code'] ?? '';
              final label = item['label'] ?? code;
              final selected = _selectedCode == code;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _selectedCode = code),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? context.colorScheme.primary
                            : const Color(0xFFE6E6E6),
                      ),
                      color: selected
                          ? context.colorScheme.primary.withOpacity(0.06)
                          : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected
                              ? context.colorScheme.primary
                              : Colors.black38,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })
                .toList(),
            TextField(
              controller: _details,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Optional details',
                filled: true,
                fillColor: const Color(0xFFF7F7F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: Color(0xFFE6E6E6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_selectedCode == null || _submitting)
                        ? null
                        : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colorScheme.primary,
                      foregroundColor: context.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _submitting
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colorScheme.onPrimary,
                            ),
                          )
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
