import 'package:furtail_app/core/theme/typography.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import '../providers/fundraising_providers.dart';

class FundraisingAccountDocumentsScreen extends ConsumerStatefulWidget {
  const FundraisingAccountDocumentsScreen({super.key});

  @override
  ConsumerState<FundraisingAccountDocumentsScreen> createState() => _FundraisingAccountDocumentsScreenState();
}

class _FundraisingAccountDocumentsScreenState extends ConsumerState<FundraisingAccountDocumentsScreen> {
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document added')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askTitle() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Document title'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'e.g., National ID, Birth Certificate'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: const Text('OK')),
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
        title: const Text('Verification Documents'),
        actions: [
          IconButton(
            tooltip: 'Add',
            icon: const Icon(Icons.add),
            onPressed: _busy ? null : _addDocument,
          ),
        ],
      ),
      body: asyncAccount.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (a) {
          if (a.documents.isEmpty) {
            return const Center(child: Text('No documents uploaded yet. Tap + to add.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: a.documents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final d = a.documents[i];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                  color: Colors.grey.withOpacity(0.06),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if ((d.mediaUrl ?? '').isNotEmpty)
                            Text(
                              d.mediaUrl!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.appText.bodySmall!.copyWith(color: Colors.black54),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: _busy ? null : () => _deleteDocument(d.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
