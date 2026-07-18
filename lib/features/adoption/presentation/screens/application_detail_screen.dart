import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_application_ui_model.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/adoption/domain/adoption_fit_score.dart';
import 'package:url_launcher/url_launcher.dart';

class ApplicationDetailScreen extends StatefulWidget {
  final int applicationId;
  final AdoptionRepository repository;

  const ApplicationDetailScreen({
    super.key,
    required this.applicationId,
    required this.repository,
  });

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  bool _isLoading = true;
  String? _error;
  AdoptionApplicationUiModel? _app;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final detail = await widget.repository.fetchAdoptionApplicationDetail(
        widget.applicationId,
      );
      if (!mounted) return;
      setState(() {
        _app = detail;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String status, {String? note}) async {
    setState(() => _isSaving = true);
    try {
      final updated = await widget.repository.updateAdoptionApplicationStatus(
        widget.applicationId,
        status,
        note: note,
      );
      if (!mounted) return;
      setState(() {
        _app = updated;
        _isSaving = false;
        _hasChanges = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to ${updated.status}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveNotes(String notes) async {
    try {
      final saved = await widget.repository.updateOwnerNotes(
        widget.applicationId,
        notes,
      );
      if (!mounted) return;
      setState(() {
        _app = _app?.copyWith(ownerNotes: saved);
        _hasChanges = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save notes: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _confirmApprove() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Approval'),
        content: const Text(
          'Approving will mark the pet as Adopted and close the listing '
          'to new applications. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus('APPROVED');
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _promptReject() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Application'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason for rejection (required)…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final reason = ctrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              _updateStatus('REJECTED', note: reason);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _promptNoteAndStatus(String status) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$status — Add note'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Optional note…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(
                status,
                note: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_hasChanges),
        ),
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            _ErrorView(message: _error!, onRetry: _load)
          else if (app != null)
            _DetailBody(
              app: app,
              onStatusUpdate: _updateStatus,
              onApprove: _confirmApprove,
              onReject: _promptReject,
              onNotesUpdate: _saveNotes,
              onScheduleInterview: () => _promptNoteAndStatus('INTERVIEW_SCHEDULED'),
              onRequestMoreInfo: () => _updateStatus('OWNER_REVIEW'),
              onShortlist: () => _updateStatus('SHORTLISTED'),
              onMarkViewed: () => _updateStatus('VIEWED'),
            ),
          if (_isSaving)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

// ── Main body ─────────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  final AdoptionApplicationUiModel app;
  final Future<void> Function(String status, {String? note}) onStatusUpdate;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onShortlist;
  final VoidCallback onMarkViewed;
  final VoidCallback onScheduleInterview;
  final VoidCallback onRequestMoreInfo;
  final Future<void> Function(String notes) onNotesUpdate;

  const _DetailBody({
    required this.app,
    required this.onStatusUpdate,
    required this.onApprove,
    required this.onReject,
    required this.onShortlist,
    required this.onMarkViewed,
    required this.onScheduleInterview,
    required this.onRequestMoreInfo,
    required this.onNotesUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final fit = AdoptionFitScore.compute(app);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              bottomPad + 90, // space for sticky bar
            ),
            children: [
              _ApplicantHeader(app: app),
              const SizedBox(height: AppSpacing.md),
              _FitScoreCard(fit: fit),
              const SizedBox(height: AppSpacing.md),
              _ApplicantSummaryCard(app: app, fit: fit),
              const SizedBox(height: AppSpacing.md),
              _QuickContactCard(app: app),
              const SizedBox(height: AppSpacing.md),
              _PetCompatibilityCard(app: app),
              if (app.message.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _MessageCard(app: app),
              ],
              if (app.answers.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _QuestionnaireCard(app: app),
              ],
              const SizedBox(height: AppSpacing.md),
              _OwnerNotesCard(notes: app.ownerNotes, onSave: onNotesUpdate),
              const SizedBox(height: AppSpacing.md),
              _ManageCard(
                app: app,
                onApprove: onApprove,
                onReject: onReject,
                onShortlist: onShortlist,
                onMarkViewed: onMarkViewed,
                onScheduleInterview: onScheduleInterview,
                onRequestMoreInfo: onRequestMoreInfo,
              ),
            ],
          ),
        ),
        _StickyBottomBar(
          app: app,
          onApprove: onApprove,
          onShortlist: onShortlist,
        ),
      ],
    );
  }
}

// ── Section: Applicant header ─────────────────────────────────────────────────

class _ApplicantHeader extends StatelessWidget {
  final AdoptionApplicationUiModel app;

  const _ApplicantHeader({required this.app});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                _AvatarWidget(url: app.applicantAvatarUrl, radius: 30),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.applicantName,
                        style: AppTypography.sectionTitle(context),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (app.applicantUsername.isNotEmpty)
                        Text(
                          '@${app.applicantUsername}',
                          style:
                              TextStyle(color: cs.outline, fontSize: 13),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (app.applicantPhone.isNotEmpty)
                            _VerifiedChip(
                              icon: Icons.phone,
                              label: 'Phone',
                            ),
                          if (app.applicantWhatsappPhone.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            _VerifiedChip(
                              icon: Icons.chat_bubble_outline,
                              label: 'WhatsApp',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Status:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                _StatusBadge(rawStatus: app.rawStatus, label: app.status),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Submitted ${app.submittedAtLabel}',
                style: TextStyle(fontSize: 11, color: cs.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section: Fit score card ───────────────────────────────────────────────────

class _FitScoreCard extends StatelessWidget {
  final AdoptionFitScore fit;

  const _FitScoreCard({required this.fit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Fit Score',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: fit.labelBg(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${fit.scoreText} — ${fit.labelText}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: fit.labelColor(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...fit.breakdown.map(
              (item) => _BreakdownRow(item: item),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final FitBreakdownItem item;

  const _BreakdownRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final (icon, color) = switch (item.state) {
      FitItemState.good => (Icons.check_circle_outline, Colors.green),
      FitItemState.warning => (Icons.warning_amber_rounded, Colors.orange),
      FitItemState.bad => (Icons.cancel_outlined, Colors.red),
      FitItemState.neutral => (Icons.remove_circle_outline, cs.outline),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(
                  item.description,
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            '+${item.points}',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color),
          ),
        ],
      ),
    );
  }
}

// ── Section: Applicant summary ────────────────────────────────────────────────

class _ApplicantSummaryCard extends StatelessWidget {
  final AdoptionApplicationUiModel app;
  final AdoptionFitScore fit;

  const _ApplicantSummaryCard({required this.app, required this.fit});

  @override
  Widget build(BuildContext context) {
    final positives = <String>[];
    final risks = <String>[];

    if (app.applicantPhone.isNotEmpty) positives.add('Contact number available');
    if (app.applicantWhatsappPhone.isNotEmpty) positives.add('WhatsApp available');
    if (app.consentToHomeCheck) positives.add('Consented to home check');
    if (app.consentToFollowUp) positives.add('Accepts follow-up visits');
    if (app.applicantExperienceSummary.isNotEmpty) {
      positives.add('Pet experience described');
    }
    if (app.answers.length >= 3) positives.add('Completed questionnaire');

    if (app.applicantPhone.isEmpty && app.applicantWhatsappPhone.isEmpty) {
      risks.add('No contact number provided');
    }
    if (!app.consentToHomeCheck) risks.add('Home check not consented');
    if (app.applicantExperienceSummary.isEmpty) {
      risks.add('No pet experience information');
    }
    if (app.applicantHouseholdSummary.isEmpty) {
      risks.add('Household not described');
    }

    if (positives.isEmpty && risks.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Applicant Summary',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            if (positives.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Strengths',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...positives.map(
                (p) => _BulletPoint(text: p, color: Colors.green.shade600),
              ),
            ],
            if (risks.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Review Points',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...risks.map(
                (r) => _BulletPoint(
                  text: r,
                  color: Colors.orange.shade700,
                  icon: Icons.warning_amber_rounded,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _BulletPoint({
    required this.text,
    required this.color,
    this.icon = Icons.check_circle_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section: Quick contact ────────────────────────────────────────────────────

class _QuickContactCard extends StatelessWidget {
  final AdoptionApplicationUiModel app;

  const _QuickContactCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final hasContact = app.applicantPhone.isNotEmpty ||
        app.applicantWhatsappPhone.isNotEmpty;
    final hasLocation = app.applicantCityAreaText.isNotEmpty ||
        app.applicantAddress.isNotEmpty;

    if (!hasContact && !hasLocation) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Contact',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            if (hasLocation) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: cs.outline),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      [
                        app.applicantCityAreaText,
                        app.applicantAddress,
                      ].where((s) => s.isNotEmpty).join(', '),
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (hasContact) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (app.applicantPhone.isNotEmpty) ...[
                    _ContactButton(
                      icon: Icons.phone_outlined,
                      label: 'Call',
                      onTap: () =>
                          _launch('tel:${app.applicantPhone.replaceAll(RegExp(r'\s+'), '')}'),
                    ),
                    _ContactButton(
                      icon: Icons.sms_outlined,
                      label: 'SMS',
                      onTap: () =>
                          _launch('sms:${app.applicantPhone.replaceAll(RegExp(r'\s+'), '')}'),
                    ),
                    _ContactButton(
                      icon: Icons.copy_outlined,
                      label: 'Copy',
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: app.applicantPhone),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Phone copied')),
                        );
                      },
                    ),
                  ],
                  if (app.applicantWhatsappPhone.isNotEmpty)
                    _ContactButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'WhatsApp',
                      onTap: () {
                        final clean = app.applicantWhatsappPhone
                            .replaceAll(RegExp(r'[^\d+]'), '');
                        _launch(
                          'https://wa.me/$clean',
                          external: true,
                        );
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _launch(String url, {bool external = false}) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      launchUrl(
        uri,
        mode: external
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
    }
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 6),
        textStyle: const TextStyle(fontSize: 12),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ── Section: Pet compatibility ────────────────────────────────────────────────

class _PetCompatibilityCard extends StatelessWidget {
  final AdoptionApplicationUiModel app;

  const _PetCompatibilityCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final pet = app.pet;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.pets, color: Colors.deepPurple),
        title: Text(
          pet.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${pet.species} • ${pet.breed}'),
        trailing: app.consentToHomeCheck
            ? const Tooltip(
                message: 'Home check consented',
                child: Icon(Icons.home_outlined, color: Colors.green),
              )
            : null,
      ),
    );
  }
}

// ── Section: Message ──────────────────────────────────────────────────────────

class _MessageCard extends StatelessWidget {
  final AdoptionApplicationUiModel app;

  const _MessageCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Message from Applicant',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              app.message,
              style: TextStyle(
                  color: cs.onSurfaceVariant, height: 1.45, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section: Questionnaire ────────────────────────────────────────────────────

class _QuestionnaireCard extends StatelessWidget {
  final AdoptionApplicationUiModel app;

  const _QuestionnaireCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Questionnaire Responses',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.md),
            ...app.answers.map((ans) => _AnswerRow(ans: ans)),
          ],
        ),
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  final Map<String, dynamic> ans;

  const _AnswerRow({required this.ans});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final q = ans['questionLabel'] ?? ans['questionKey'] ?? 'Question';
    final a = ans['answerText']?.toString().trim() ?? '';
    final isEmpty = a.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  q.toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              if (isEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Missing',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isEmpty ? 'No answer provided' : a,
            style: TextStyle(
              color: isEmpty ? cs.outline : cs.onSurfaceVariant,
              fontSize: 13,
              height: 1.35,
              fontStyle: isEmpty ? FontStyle.italic : null,
            ),
          ),
          const Divider(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

// ── Section: Owner notes ──────────────────────────────────────────────────────

class _OwnerNotesCard extends StatefulWidget {
  final String notes;
  final Future<void> Function(String) onSave;

  const _OwnerNotesCard({required this.notes, required this.onSave});

  @override
  State<_OwnerNotesCard> createState() => _OwnerNotesCardState();
}

class _OwnerNotesCardState extends State<_OwnerNotesCard> {
  late final TextEditingController _ctrl;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.notes);
  }

  @override
  void didUpdateWidget(_OwnerNotesCard old) {
    super.didUpdateWidget(old);
    if (!_editing && old.notes != widget.notes) {
      _ctrl.text = widget.notes;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(_ctrl.text.trim());
    if (mounted) setState(() { _saving = false; _editing = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 14),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Private Owner Notes',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                if (!_editing)
                  TextButton(
                    onPressed: () => setState(() => _editing = true),
                    child: const Text('Edit'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_editing)
              Column(
                children: [
                  TextField(
                    controller: _ctrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Add private notes for this applicant…',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(AppSpacing.sm),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _ctrl.text = widget.notes;
                          setState(() => _editing = false);
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ],
              )
            else
              Text(
                widget.notes.isEmpty
                    ? 'No notes yet. Tap Edit to add.'
                    : widget.notes,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.notes.isEmpty
                      ? cs.outline
                      : cs.onSurfaceVariant,
                  fontStyle: widget.notes.isEmpty ? FontStyle.italic : null,
                  height: 1.4,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Section: Manage card ──────────────────────────────────────────────────────

class _ManageCard extends StatelessWidget {
  final AdoptionApplicationUiModel app;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onShortlist;
  final VoidCallback onMarkViewed;
  final VoidCallback onScheduleInterview;
  final VoidCallback onRequestMoreInfo;

  const _ManageCard({
    required this.app,
    required this.onApprove,
    required this.onReject,
    required this.onShortlist,
    required this.onMarkViewed,
    required this.onScheduleInterview,
    required this.onRequestMoreInfo,
  });

  @override
  Widget build(BuildContext context) {
    final status = app.rawStatus.toUpperCase();
    final isTerminal = status == 'APPROVED' || status == 'REJECTED';
    if (isTerminal) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Application Status',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.sm),
              _StatusBadge(rawStatus: app.rawStatus, label: app.status),
              if (app.rejectedReason.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Reason: ${app.rejectedReason}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Application',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (status != 'VIEWED')
                  _ActionButton(
                    label: 'Mark Viewed',
                    icon: Icons.visibility_outlined,
                    onTap: onMarkViewed,
                  ),
                if (status != 'SHORTLISTED')
                  _ActionButton(
                    label: 'Shortlist',
                    icon: Icons.star_outline_rounded,
                    onTap: onShortlist,
                  ),
                if (status != 'INTERVIEW_SCHEDULED')
                  _ActionButton(
                    label: 'Schedule Interview',
                    icon: Icons.calendar_today_outlined,
                    onTap: onScheduleInterview,
                  ),
                _ActionButton(
                  label: 'Request More Info',
                  icon: Icons.help_outline_rounded,
                  onTap: onRequestMoreInfo,
                ),
                _ActionButton(
                  label: 'Approve',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  onTap: onApprove,
                ),
                _ActionButton(
                  label: 'Reject',
                  icon: Icons.cancel_outlined,
                  color: Colors.red,
                  onTap: onReject,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colorScheme.primary;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: c),
      label: Text(label, style: TextStyle(color: c)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: c.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 6),
        textStyle: const TextStyle(fontSize: 12),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ── Sticky bottom bar ─────────────────────────────────────────────────────────

class _StickyBottomBar extends StatelessWidget {
  final AdoptionApplicationUiModel app;
  final VoidCallback onApprove;
  final VoidCallback onShortlist;

  const _StickyBottomBar({
    required this.app,
    required this.onApprove,
    required this.onShortlist,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final status = app.rawStatus.toUpperCase();
    final isTerminal = status == 'APPROVED' || status == 'REJECTED';
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm + bottomPad,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (app.applicantPhone.isNotEmpty)
            _BarButton(
              icon: Icons.phone_outlined,
              label: 'Call',
              onTap: () => _launchTel(app.applicantPhone),
              outlined: true,
            ),
          if (app.applicantWhatsappPhone.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            _BarButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'WhatsApp',
              onTap: () => _launchWhatsapp(app.applicantWhatsappPhone),
              outlined: true,
            ),
          ],
          const Spacer(),
          if (!isTerminal && status != 'SHORTLISTED')
            _BarButton(
              icon: Icons.star_outline_rounded,
              label: 'Shortlist',
              onTap: onShortlist,
              outlined: true,
            ),
          if (!isTerminal) ...[
            const SizedBox(width: AppSpacing.sm),
            _BarButton(
              icon: Icons.check_rounded,
              label: 'Approve',
              onTap: onApprove,
              filled: true,
              color: Colors.green,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _launchTel(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'\s+'), '')}');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _launchWhatsapp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;
  final bool filled;
  final Color? color;

  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.outlined = false,
    this.filled = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final c = color ?? cs.primary;

    if (filled) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: c,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          textStyle: const TextStyle(fontSize: 13),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: c),
      label: Text(label, style: TextStyle(color: c)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: c.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        textStyle: const TextStyle(fontSize: 13),
      ),
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _AvatarWidget extends StatelessWidget {
  final String url;
  final double radius;

  const _AvatarWidget({required this.url, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty ? Icon(Icons.person, size: radius) : null,
    );
  }
}

class _VerifiedChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _VerifiedChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.green.shade700),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String rawStatus;
  final String label;

  const _StatusBadge({required this.rawStatus, required this.label});

  Color _color() {
    switch (rawStatus.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
      case 'CANCELLED':
        return Colors.red;
      case 'SHORTLISTED':
        return Colors.purple;
      case 'INTERVIEW_SCHEDULED':
        return Colors.orange;
      case 'VIEWED':
      case 'OWNER_REVIEW':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontWeight: FontWeight.bold, color: c, fontSize: 12),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not load application',
              style: AppTypography.sectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
