import 'dart:io';

import 'package:flutter/material.dart';
import 'package:furtail_app/features/media/composer/media_composer_controller.dart';
import 'package:furtail_app/features/media/composer/media_draft_item.dart';

class MediaComposerList extends StatelessWidget {
  const MediaComposerList({
    super.key,
    required this.controller,
    this.onEditItem,
  });

  final MediaComposerController controller;
  final Future<void> Function(MediaDraftItem item)? onEditItem;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final items = controller.items;
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final width =
                constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final columns = width >= 1100
                ? 4
                : width >= 760
                ? 3
                : width >= 520
                ? 2
                : 1;
            final spacing = 12.0;
            final cardWidth = columns == 1
                ? width
                : ((width - spacing * (columns - 1)) / columns)
                      .clamp(170.0, 240.0)
                      .toDouble();

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final item in items)
                  SizedBox(
                    width: cardWidth,
                    child: _ComposerCard(
                      key: ValueKey(item.id),
                      item: item,
                      onEdit: onEditItem == null
                          ? null
                          : () => onEditItem!(item),
                      onRetry: () => controller.retryItem(item.id),
                      onRemove: () => controller.removeItem(item.id),
                      onCancel: () => controller.cancelItem(item.id),
                      onSetCover: () => controller.setCover(item.id),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

enum _ComposerCardAction { edit, retry, remove, cancel, setCover }

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    super.key,
    required this.item,
    required this.onRetry,
    required this.onRemove,
    required this.onCancel,
    required this.onSetCover,
    this.onEdit,
  });

  final MediaDraftItem item;
  final Future<void> Function()? onEdit;
  final Future<void> Function() onRetry;
  final Future<void> Function() onRemove;
  final Future<void> Function() onCancel;
  final Future<void> Function() onSetCover;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: key,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
        color: cs.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.08,
            child: Stack(
              children: [
                Positioned.fill(child: _preview()),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Row(
                    children: [
                      _Badge(
                        label: item.isCover ? 'Cover' : _typeLabel(item),
                        backgroundColor: item.isCover
                            ? cs.primary
                            : Colors.black.withValues(alpha: 0.65),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: _ActionMenu(
                    onEdit: onEdit != null && !item.isUploading ? onEdit : null,
                    onRetry: item.hasFailed || item.isCancelled
                        ? onRetry
                        : null,
                    onRemove: item.isUploading || item.isPreparing
                        ? null
                        : onRemove,
                    onCancel: item.isUploading || item.isPreparing
                        ? onCancel
                        : null,
                    onSetCover: item.isCover ? null : onSetCover,
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: _StatusPill(item: item),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatFileSize(item.originalSizeBytes),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (item.isUploading) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: item.progress.clamp(0, 1).toDouble(),
                  ),
                ],
                if (item.hasFailed || item.isCancelled) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Retry'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline, size: 14),
                        label: const Text('Remove'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    if (item.isDocument) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F5F5), Color(0xFFE8EEF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.description_outlined, size: 42),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  item.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final thumbPath = item.thumbnailPath;
    if (thumbPath != null &&
        thumbPath.isNotEmpty &&
        File(thumbPath).existsSync()) {
      return Image.file(
        File(thumbPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _previewPlaceholder(item),
      );
    }

    final localPath = item.localPath;
    if (item.isImage &&
        localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync()) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _previewPlaceholder(item),
      );
    }

    final previewUrl = item.remoteThumbnailUrl ?? item.previewUrl;
    if (previewUrl != null && previewUrl.isNotEmpty) {
      return Image.network(
        previewUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _previewPlaceholder(item),
      );
    }

    return _previewPlaceholder(item);
  }

  Widget _previewPlaceholder(MediaDraftItem item) {
    return Container(
      color: Colors.black12,
      child: Center(
        child: Icon(
          item.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
          size: 36,
        ),
      ),
    );
  }

  String _typeLabel(MediaDraftItem item) {
    if (item.isImage) return 'Photo';
    if (item.isVideo) return 'Video';
    return 'Document';
  }
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({
    required this.onEdit,
    required this.onRetry,
    required this.onRemove,
    required this.onCancel,
    required this.onSetCover,
  });

  final Future<void> Function()? onEdit;
  final Future<void> Function()? onRetry;
  final Future<void> Function()? onRemove;
  final Future<void> Function()? onCancel;
  final Future<void> Function()? onSetCover;

  @override
  Widget build(BuildContext context) {
    final actions = <PopupMenuEntry<_ComposerCardAction>>[];
    if (onEdit != null) {
      actions.add(
        const PopupMenuItem<_ComposerCardAction>(
          value: _ComposerCardAction.edit,
          child: Text('Edit'),
        ),
      );
    }
    if (onRetry != null) {
      actions.add(
        const PopupMenuItem<_ComposerCardAction>(
          value: _ComposerCardAction.retry,
          child: Text('Retry'),
        ),
      );
    }
    if (onSetCover != null) {
      actions.add(
        const PopupMenuItem<_ComposerCardAction>(
          value: _ComposerCardAction.setCover,
          child: Text('Set as cover'),
        ),
      );
    }
    if (onCancel != null) {
      actions.add(
        const PopupMenuItem<_ComposerCardAction>(
          value: _ComposerCardAction.cancel,
          child: Text('Cancel upload'),
        ),
      );
    }
    if (onRemove != null) {
      actions.add(
        const PopupMenuItem<_ComposerCardAction>(
          value: _ComposerCardAction.remove,
          child: Text('Remove'),
        ),
      );
    }
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<_ComposerCardAction>(
      tooltip: 'Media actions',
      iconSize: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) {
        switch (action) {
          case _ComposerCardAction.edit:
            onEdit?.call();
            break;
          case _ComposerCardAction.retry:
            onRetry?.call();
            break;
          case _ComposerCardAction.remove:
            onRemove?.call();
            break;
          case _ComposerCardAction.cancel:
            onCancel?.call();
            break;
          case _ComposerCardAction.setCover:
            onSetCover?.call();
            break;
        }
      },
      itemBuilder: (context) => actions,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.item});

  final MediaDraftItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = switch (item.state) {
      MediaDraftState.local => 'Ready to upload',
      MediaDraftState.preparing => 'Preparing',
      MediaDraftState.uploading =>
        'Uploading ${(item.progress * 100).round()}%',
      MediaDraftState.uploaded => 'Uploaded',
      MediaDraftState.processing => 'Processing',
      MediaDraftState.ready => 'Ready',
      MediaDraftState.failed => 'Upload failed',
      MediaDraftState.cancelled => 'Cancelled',
    };
    final background = switch (item.state) {
      MediaDraftState.failed ||
      MediaDraftState.cancelled => cs.errorContainer.withValues(alpha: 0.95),
      _ => Colors.black.withValues(alpha: 0.62),
    };
    final foreground = switch (item.state) {
      MediaDraftState.failed ||
      MediaDraftState.cancelled => cs.onErrorContainer,
      _ => Colors.white,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        item.errorMessage != null && (item.hasFailed || item.isCancelled)
            ? item.errorMessage!
            : label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.backgroundColor});

  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes <= 0) return '0 KB';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
