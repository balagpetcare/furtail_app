import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_application_ui_model.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';

class ApplicationDetailScreen extends StatefulWidget {
  final int applicationId;
  final AdoptionRepository repository;

  const ApplicationDetailScreen({
    super.key,
    required this.applicationId,
    required this.repository,
  });

  @override
  State<ApplicationDetailScreen> createState() => _ApplicationDetailScreenState();
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
    setState(() {
      _isLoading = true;
    });
    try {
      final detail = await widget.repository.fetchAdoptionApplicationDetail(widget.applicationId);
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
    setState(() {
      _isSaving = true;
    });
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
        SnackBar(content: Text('Application status updated to $status')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _promptNoteAndStatus(String status) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reason for $status'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter reason/notes here...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateStatus(status, note: controller.text.trim());
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Color _statusColor(String status, ColorScheme cs) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
      case 'CANCELLED':
        return Colors.red;
      case 'SHORTLISTED':
        return Colors.purple;
      case 'INTERVIEW SCHEDULED':
      case 'INTERVIEW_SCHEDULED':
        return Colors.orange;
      case 'VIEWED':
      case 'OWNER_REVIEW':
        return Colors.blue;
      default:
        return cs.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final app = _app;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _hasChanges) {
          // Notify the list screen that it should reload
          // (Handled by Navigator.pop value check)
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Application Detail'),
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
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: AppSpacing.md),
                      Text('Could not load application', style: AppTypography.sectionTitle(context)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: AppSpacing.lg),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            else if (app != null)
              ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // Header Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundImage: app.applicantAvatarUrl.isNotEmpty
                                    ? NetworkImage(app.applicantAvatarUrl)
                                    : null,
                                child: app.applicantAvatarUrl.isEmpty
                                    ? const Icon(Icons.person, size: 28)
                                    : null,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      app.applicantName,
                                      style: AppTypography.sectionTitle(context),
                                    ),
                                    Text(
                                      '@${app.applicantUsername}',
                                      style: TextStyle(color: cs.outline, fontSize: 13),
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
                              Text('Application Status:', style: AppTypography.menuTitle(context)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(app.status, cs).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _statusColor(app.status, cs).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  app.status,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _statusColor(app.status, cs),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Submitted on ${app.submittedAtLabel}',
                              style: TextStyle(color: cs.outline, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Pet summary card
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.pets, color: Colors.purple),
                      title: Text(app.pet.name, style: AppTypography.menuTitle(context)),
                      subtitle: Text('${app.pet.species} • ${app.pet.breed ?? "Unknown breed"}'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Message Card
                  if (app.message.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Message from Applicant', style: AppTypography.menuTitle(context)),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              app.message,
                              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Questionnaire Answers
                  if (app.answers.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Questionnaire Responses', style: AppTypography.menuTitle(context)),
                            const SizedBox(height: AppSpacing.md),
                            ...app.answers.map(
                              (ans) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ans['questionLabel'] ?? ans['questionKey'] ?? 'Question',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      ans['answerText'] ?? 'No answer provided',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        height: 1.3,
                                      ),
                                    ),
                                    const Divider(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Actions Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Manage Application', style: AppTypography.menuTitle(context)),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              ElevatedButton(
                                onPressed: () => _updateStatus('VIEWED'),
                                child: const Text('Mark Viewed'),
                              ),
                              ElevatedButton(
                                onPressed: () => _updateStatus('SHORTLISTED'),
                                child: const Text('Shortlist'),
                              ),
                              ElevatedButton(
                                onPressed: () => _updateStatus('INTERVIEW_SCHEDULED'),
                                child: const Text('Schedule Interview'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade50,
                                  foregroundColor: Colors.green.shade800,
                                ),
                                onPressed: () => _updateStatus('APPROVED'),
                                child: const Text('Approve'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade50,
                                  foregroundColor: Colors.red.shade800,
                                ),
                                onPressed: () => _promptNoteAndStatus('REJECTED'),
                                child: const Text('Reject'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade100,
                                  foregroundColor: Colors.grey.shade800,
                                ),
                                onPressed: () => _promptNoteAndStatus('CANCELLED'),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            if (_isSaving)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
