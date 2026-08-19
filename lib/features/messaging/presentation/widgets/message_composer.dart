import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:furtail_app/core/theme/theme_extensions.dart';

import '../../data/message_media_preparation_service.dart';
import '../../data/messaging_service.dart'
    show kMaxMessageLength, MessagingMediaSettings;
import '../../data/models/message_model.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
    this.disabledReason,
    this.editingMessage,
    this.onCancelEdit,
    this.onTextChanged,
    this.mediaSettings = MessagingMediaSettings.fallback,
  });

  final void Function(String text, List<File> attachments) onSend;
  final String? disabledReason;
  final MessageModel? editingMessage;
  final VoidCallback? onCancelEdit;
  final ValueChanged<String>? onTextChanged;

  /// Client-safe messaging media policy (COMMAND 01's admin-configurable
  /// settings) — used purely for an instant client-side precheck before
  /// spending an upload round trip (Part 10). The server independently
  /// re-validates every upload regardless of what this reports.
  final MessagingMediaSettings mediaSettings;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;
  final List<File> _attachments = [];
  final _mediaPreparation = const MessageMediaPreparationService();

  @override
  void initState() {
    super.initState();
    final editing = widget.editingMessage;
    if (editing != null) {
      _controller.text = editing.body;
    }
  }

  @override
  void didUpdateWidget(covariant MessageComposer old) {
    super.didUpdateWidget(old);
    final editing = widget.editingMessage;
    if (editing != null && editing.id != old.editingMessage?.id) {
      _controller.text = editing.body;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      _focusNode.requestFocus();
    } else if (editing == null && old.editingMessage != null) {
      _controller.clear();
      _attachments.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Widget _attachmentFilenameTile(String filename) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Text(
          filename,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: context.mutedTextColor),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  bool get _canSubmit =>
      (_controller.text.trim().isNotEmpty || _attachments.isNotEmpty) &&
      !_sending;

  Future<String?> _showAttachmentSheet() {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.mic_none_outlined),
              title: const Text('Audio'),
              onTap: () => Navigator.pop(ctx, 'audio'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Real Android devices frequently hand pickers back `content://`-backed
  /// paths (SAF/DocumentsProvider), which `dart:io File` cannot open at
  /// all — every downstream `File(path)` operation (size precheck, local
  /// thumbnail preview, and the multipart upload itself) would silently
  /// fail on exactly those devices, producing the reported "empty preview
  /// + Failed · Tap to retry" without ever reaching the network. Reading
  /// bytes through the picker plugin's own channel (which *can* resolve
  /// `content://` via the platform's ContentResolver) and writing them to
  /// a real file this app owns guarantees every later `dart:io` call has
  /// an actual filesystem path to work with, regardless of what the
  /// picker returned.
  Future<File> _materializeXFile(XFile picked) async {
    final bytes = await picked.readAsBytes();
    final dir = await getTemporaryDirectory();
    final safeName = p.basename(
      picked.name.isNotEmpty ? picked.name : picked.path,
    );
    final target = File(
      p.join(
        dir.path,
        'furtail_attach_${DateTime.now().microsecondsSinceEpoch}_$safeName',
      ),
    );
    await target.writeAsBytes(bytes, flush: true);
    if (kDebugMode) {
      debugPrint('[MediaUpload] selected type=image/video size=${bytes.length}');
    }
    return target;
  }

  Future<File?> _materializePlatformFile(PlatformFile picked) async {
    var bytes = picked.bytes;
    if (bytes == null && picked.path != null) {
      try {
        bytes = await File(picked.path!).readAsBytes();
      } catch (_) {
        bytes = null;
      }
    }
    if (bytes == null) return null;
    final dir = await getTemporaryDirectory();
    final safeName = p.basename(picked.name);
    final target = File(
      p.join(
        dir.path,
        'furtail_attach_${DateTime.now().microsecondsSinceEpoch}_$safeName',
      ),
    );
    await target.writeAsBytes(bytes, flush: true);
    if (kDebugMode) {
      debugPrint('[MediaUpload] selected type=audio size=${bytes.length}');
    }
    return target;
  }

  /// Client-side precheck (Part 10) — reads the local file's actual size
  /// and rejects it before ever starting an upload if it exceeds the
  /// current server/admin policy for that media category. The server
  /// remains authoritative regardless: this only saves the round trip for
  /// the common case of an obviously-oversized pick.
  Future<bool> _precheckSize(File file, int maxBytes) async {
    final bytes = await file.length();
    if (bytes <= maxBytes) return true;
    if (!mounted) return false;
    final maxMb = (maxBytes / (1024 * 1024)).round();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Maximum media size is $maxMb MB.')));
    return false;
  }

  /// Runs a picked photo through [MessageMediaPreparationService] (resize +
  /// adaptive JPEG compression) before it ever becomes an attachment — the
  /// composer's local preview and the eventual upload both use this
  /// already-optimized file, never the raw camera/gallery original. Falls
  /// back to the untouched source file if compression itself throws (e.g.
  /// an undecodable format) rather than blocking the attachment entirely.
  Future<void> _addPreparedImage(File file) async {
    File prepared = file;
    try {
      prepared = await _mediaPreparation.prepareImage(file);
    } catch (_) {
      prepared = file;
    }
    if (!mounted) return;
    setState(() => _attachments.add(prepared));
  }

  Future<void> _pickFiles() async {
    if (!widget.mediaSettings.mediaMessagingEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Media messaging is currently unavailable.'),
        ),
      );
      return;
    }
    try {
      final source = await _showAttachmentSheet();
      if (source == null || !mounted) return;

      switch (source) {
        case 'image':
          final picked = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            imageQuality: 90,
          );
          if (picked != null && mounted) {
            final file = await _materializeXFile(picked);
            if (mounted &&
                await _precheckSize(
                  file,
                  widget.mediaSettings.imageMaxSourceBytes,
                )) {
              await _addPreparedImage(file);
            }
          }
        case 'video':
          final picked = await ImagePicker().pickVideo(
            source: ImageSource.gallery,
          );
          if (picked != null && mounted) {
            final file = await _materializeXFile(picked);
            if (mounted &&
                await _precheckSize(
                  file,
                  widget.mediaSettings.videoMaxSourceBytes,
                )) {
              setState(() => _attachments.add(file));
            }
          }
        case 'camera':
          final picked = await ImagePicker().pickImage(
            source: ImageSource.camera,
            imageQuality: 90,
          );
          if (picked != null && mounted) {
            final file = await _materializeXFile(picked);
            if (mounted &&
                await _precheckSize(
                  file,
                  widget.mediaSettings.imageMaxSourceBytes,
                )) {
              await _addPreparedImage(file);
            }
          }
        case 'audio':
          final result = await FilePicker.platform.pickFiles(
            type: FileType.audio,
            withData: true,
          );
          final picked = result?.files.single;
          if (picked != null && mounted) {
            final file = await _materializePlatformFile(picked);
            if (file == null) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not read the selected audio file.'),
                  ),
                );
              }
              return;
            }
            if (mounted &&
                await _precheckSize(
                  file,
                  widget.mediaSettings.audioMaxSourceBytes,
                )) {
              setState(() => _attachments.add(file));
            }
          }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open media: ${e.toString().replaceAll("Exception: ", "")}',
            ),
          ),
        );
      }
    }
  }

  bool _isImagePath(String path) {
    final ext = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext);
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _attachments.isEmpty) || _sending) return;

    final isEditing = widget.editingMessage != null;
    setState(() => _sending = true);

    final currentAttachments = List<File>.from(_attachments);
    if (!isEditing) {
      _controller.clear();
      _attachments.clear();
    }

    widget.onSend(text, currentAttachments);

    if (mounted) setState(() => _sending = false);
  }

  Widget _buildAttachmentsTray() {
    if (_attachments.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 80,
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final file = _attachments[index];
          final filename = file.path.split('/').last;
          final isImage = _isImagePath(file.path);

          return Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colorScheme.outlineVariant),
                ),
                child: isImage
                    ? Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _attachmentFilenameTile(filename),
                      )
                    : _attachmentFilenameTile(filename),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => _removeAttachment(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final disabledReason = widget.disabledReason;

    if (disabledReason != null) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: context.mutedTextColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  disabledReason,
                  style: TextStyle(
                    color: context.mutedTextColor,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isEditing = widget.editingMessage != null;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isEditing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: cs.primaryContainer.withValues(alpha: 0.35),
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Editing message',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        widget.onCancelEdit?.call();
                      },
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _buildAttachmentsTray(),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: isEditing ? null : _pickFiles,
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: isEditing ? context.mutedTextColor : cs.primary,
                    ),
                  ),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 6,
                        maxLength: kMaxMessageLength,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        buildCounter:
                            (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                        decoration: InputDecoration(
                          hintText: isEditing ? 'Edit message…' : 'Message…',
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (text) {
                          setState(() {});
                          if (!isEditing) widget.onTextChanged?.call(text);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: isEditing ? 'Save edit' : 'Send',
                    onPressed: _canSubmit ? _submit : null,
                    icon: Icon(
                      isEditing ? Icons.check_rounded : Icons.send_rounded,
                      color: _canSubmit ? cs.primary : context.mutedTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
