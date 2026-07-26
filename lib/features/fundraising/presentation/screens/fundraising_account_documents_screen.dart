import 'package:furtail_app/core/theme/furtail_design_tokens.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:furtail_app/features/fundraising/data/fundraising_error_mapper.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_status_views.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import '../providers/fundraising_providers.dart';
import 'fundraising_document_preview_screen.dart';

class FundraisingAccountDocumentsScreen extends ConsumerStatefulWidget {
  const FundraisingAccountDocumentsScreen({super.key});

  @override
  ConsumerState<FundraisingAccountDocumentsScreen> createState() =>
      _FundraisingAccountDocumentsScreenState();
}

class _FundraisingAccountDocumentsScreenState
    extends ConsumerState<FundraisingAccountDocumentsScreen> {
  final _postsDs = PostsRemoteDs();
  bool _busy = false;

  Future<void> _addDocument() async {
    if (_busy) return;
    final title = await _askTitle();
    if (title == null || title.trim().isEmpty) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() => _busy = true);
    try {
      final mediaId = await _postsDs.uploadMedia(File(path));
      final repo = ref.read(fundraisingRepositoryProvider);
      await repo.addDocument(title: title.trim(), mediaId: mediaId);
      ref.invalidate(fundraisingMyAccountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document added')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFundraisingSafeError(e).message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteDocument(int id) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(fundraisingRepositoryProvider);
      await repo.deleteDocument(id);
      ref.invalidate(fundraisingMyAccountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFundraisingSafeError(e).message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _replaceDocument(FundraisingAccountDocument document) async {
    if (_busy) return;
    final title = await _askTitle(initialValue: document.title);
    if (title == null || title.trim().isEmpty) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() => _busy = true);
    try {
      final mediaId = await _postsDs.uploadMedia(File(path));
      final repo = ref.read(fundraisingRepositoryProvider);
      await repo.addDocument(title: title.trim(), mediaId: mediaId);
      await repo.deleteDocument(document.id);
      ref.invalidate(fundraisingMyAccountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document replaced')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFundraisingSafeError(e).message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewDocument(FundraisingAccountDocument document) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FundraisingDocumentPreviewScreen(document: document),
      ),
    );
  }

  Future<String?> _askTitle({String? initialValue}) async {
    final ctrl = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Document title'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'e.g., National ID, Birth Certificate',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncAccount = ref.watch(fundraisingMyAccountProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Verification documents'),
        actions: [
          IconButton(
            tooltip: 'Add',
            icon: const Icon(Icons.add),
            onPressed: _busy ? null : _addDocument,
          ),
        ],
      ),
      body: asyncAccount.when(
        loading: () => const FundraisingLoadingView(),
        error: (e, _) {
          final safeError = mapFundraisingSafeError(e);
          return FundraisingErrorView(
            title: fundraisingErrorTitle(safeError),
            message: fundraisingErrorDescription(safeError),
            onRetry: () async {
              ref.invalidate(fundraisingMyAccountProvider);
              await ref.read(fundraisingMyAccountProvider.future);
            },
            onBack: () => Navigator.of(context).maybePop(),
          );
        },
        data: (a) {
          final documents =
              a?.documents ?? const <FundraisingAccountDocument>[];
          if (documents.isEmpty) {
            return FundraisingEmptyState(
              icon: Icons.description_outlined,
              title: 'No verification documents yet',
              message:
                  'Upload a National ID, birth registration, or another accepted identity document so reviewers can verify your fundraising account.',
              actionLabel: 'Upload document',
              onAction: _busy ? null : _addDocument,
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            itemCount: documents.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final d = documents[i];
              return _DocumentCard(
                document: d,
                busy: _busy,
                onPreview: () => _previewDocument(d),
                onReplace: () => _replaceDocument(d),
                onDelete: () => _deleteDocument(d.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.busy,
    required this.onPreview,
    required this.onReplace,
    required this.onDelete,
  });

  final FundraisingAccountDocument document;
  final bool busy;
  final VoidCallback onPreview;
  final VoidCallback onReplace;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final mediaType = (document.mediaType ?? '').toUpperCase();
    final isImage = mediaType == 'IMAGE';
    final previewHint = isImage
        ? 'Image'
        : mediaType.contains('PDF')
        ? 'PDF'
        : (document.safeFileName.toLowerCase().endsWith('.pdf')
              ? 'PDF'
              : 'Attachment');
    final uploadedAt = document.createdAt;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FurtailDesignTokens.border(context)),
        color: FurtailDesignTokens.cardBackground(context),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPreview,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isImage ? Icons.image_outlined : Icons.description_outlined),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    document.safeFileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.appText.bodySmall!.copyWith(
                      color: FurtailDesignTokens.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _MetaChip(label: previewHint),
                      if (uploadedAt != null)
                        _MetaChip(
                          label:
                              'Uploaded ${DateFormat.yMMMd().format(uploadedAt)}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              onSelected: (value) async {
                if (value == 'view') {
                  onPreview();
                } else if (value == 'replace' && !busy) {
                  onReplace();
                } else if (value == 'delete' && !busy) {
                  onDelete();
                } else if (value == 'open_external') {
                  final uri = Uri.tryParse(document.mediaUrl ?? '');
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                const PopupMenuItem(value: 'view', child: Text('View')),
                const PopupMenuItem(value: 'replace', child: Text('Replace')),
                const PopupMenuItem(
                  value: 'open_external',
                  child: Text('Open externally'),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  enabled: !busy,
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
