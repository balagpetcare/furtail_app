import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:furtail_app/core/widgets/authenticated_network_image.dart';
import 'package:furtail_app/core/media/fullscreen_gallery_viewer.dart';
import 'package:furtail_app/core/media/fullscreen_video_player_screen.dart';

import '../../data/models/message_model.dart';
import 'audio_message_bubble.dart';
import 'conversation_tile.dart' show formatMessageTimestamp;

/// Max attachment thumbnail footprint inside a bubble — real image/video
/// aspect ratio is preserved within this box (never a forced square crop),
/// per the "70-75% of screen width, reasonable max height" rule.
const double _kAttachmentMaxWidth = 220;
const double _kAttachmentMaxHeight = 260;

String _formatDuration(int? ms) {
  if (ms == null || ms <= 0) return '';
  final d = Duration(milliseconds: ms);
  final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onRetry,
    this.showAvatar = false,
    this.groupedWithPrevious = false,
    this.showTimestamp = true,
    this.onEdit,
    this.onDelete,
    this.isMutating = false,
    this.otherUserAvatarUrl,
    this.otherUserName = 'Furtail Member',
    this.showSeenAvatar = false,
  });

  final MessageModel message;
  final bool isMine;
  final VoidCallback? onRetry;

  /// Whether to show the sender's avatar beside this bubble — only true for
  /// the last bubble of a consecutive incoming group, matching modern
  /// messenger conventions (never repeated on every single bubble).
  final bool showAvatar;

  /// Whether the previous (older) message was from the same sender on the
  /// same day — tightens the vertical gap so consecutive messages read as
  /// one visual group.
  final bool groupedWithPrevious;

  /// Whether to render the relative-time caption under this bubble. True
  /// only for the last (most recent) bubble of a consecutive same-sender
  /// group — Messenger-style: a run of quick messages shows one timestamp
  /// at the end, not one under every single bubble. Ignored (always shown)
  /// for failed/pending status text, since that's actionable, not merely
  /// decorative time context.
  final bool showTimestamp;

  /// Only set for the caller's own, sent, not-yet-deleted messages.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isMutating;

  final String? otherUserAvatarUrl;
  final String otherUserName;

  /// Messenger-style "seen" marker: true only for the single latest own
  /// outgoing message the other participant has actually read (see
  /// `ThreadState.latestSeenOwnMessageId`) — never shown on every read
  /// message, and never on an incoming (not-mine) bubble.
  final bool showSeenAvatar;

  Future<void> _showActions(BuildContext context) async {
    if (message.isDeleted || message.isPending) return;
    final cs = context.colorScheme;
    final action = await showModalBottomSheet<_BubbleAction>(
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
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () => Navigator.pop(ctx, _BubbleAction.copy),
            ),
            if (isMine && onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(ctx, _BubbleAction.edit),
              ),
            if (isMine && onDelete != null)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: cs.error),
                title: Text('Unsend', style: TextStyle(color: cs.error)),
                onTap: () => Navigator.pop(ctx, _BubbleAction.delete),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    switch (action) {
      case _BubbleAction.copy:
        await Clipboard.setData(ClipboardData(text: message.body));
      case _BubbleAction.edit:
        onEdit?.call();
      case _BubbleAction.delete:
        onDelete?.call();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    if (message.isDeleted) {
      return _buildTombstone(context);
    }

    final bubbleColor = isMine ? cs.primary : cs.surfaceContainerHighest;
    final textColor = isMine ? cs.onPrimary : cs.onSurface;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.hasAttachments) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: message.attachments.map((attachment) {
                if (attachment.isFailed) {
                  return _FailedAttachmentTile(
                    attachment: attachment,
                    onRetry: onRetry,
                  );
                }

                if (attachment.isUploading) {
                  return _UploadingAttachmentTile(attachment: attachment);
                }

                if (attachment.isAudio && attachment.url != null) {
                  return AudioMessageBubble(
                    url: attachment.url!,
                    isMine: isMine,
                    durationMs: attachment.durationMs,
                  );
                }

                // Real aspect ratio (never a forced square) — falls back to
                // 4:3 only when the backend hasn't populated width/height
                // yet (media still mid-pipeline, or a legacy row).
                final ratio = attachment.aspectRatio ?? (4 / 3);
                final boxWidth = _kAttachmentMaxWidth;
                final boxHeight = (boxWidth / ratio).clamp(
                  120.0,
                  _kAttachmentMaxHeight,
                );

                if (attachment.isImage && attachment.url != null) {
                  final thumb = attachment.thumbnailUrl ?? attachment.url!;
                  return GestureDetector(
                    onTap: () {
                      final imageAttachments = message.attachments
                          .where((a) => a.isImage && a.url != null)
                          .toList();
                      final urls = imageAttachments.map((a) => a.url!).toList();
                      final initialIndex = imageAttachments.indexOf(attachment);
                      if (urls.isNotEmpty && initialIndex >= 0) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FullscreenGalleryViewer(
                              urls: urls,
                              initialIndex: initialIndex,
                              heroTagPrefix: 'msg_${message.id}_',
                              authenticated: true,
                            ),
                          ),
                        );
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: boxWidth,
                        height: boxHeight,
                        // Direct-message attachments are private per-
                        // conversation (see `/api/v1/media/*`'s participant
                        // check on the backend) — a plain unauthenticated
                        // network image request 403s. This fetches through
                        // the app's own authenticated API client instead.
                        child: AuthenticatedNetworkImage(
                          imageUrl: thumb,
                          width: boxWidth,
                          height: boxHeight,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                }

                if (attachment.isVideo && attachment.url != null) {
                  final poster = attachment.thumbnailUrl;
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FullscreenVideoPlayerScreen(
                            url: attachment.url!,
                            posterUrl: poster,
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: boxWidth,
                        height: boxHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (poster != null)
                              AuthenticatedNetworkImage(
                                imageUrl: poster,
                                width: boxWidth,
                                height: boxHeight,
                                fit: BoxFit.cover,
                              )
                            else
                              Container(color: Colors.black87),
                            Container(
                              color: Colors.black.withValues(alpha: 0.15),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.play_circle_fill,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                            if (attachment.durationMs != null)
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _formatDuration(attachment.durationMs),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Fallback for files
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.insert_drive_file, size: 20, color: textColor),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          attachment.filename ?? 'File',
                          style: TextStyle(color: textColor, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (message.body.isNotEmpty) const SizedBox(height: 8),
          ],
          if (message.body.isNotEmpty)
            Text(
              message.body,
              style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
              softWrap: true,
            ),
          if (message.isEdited) ...[
            const SizedBox(height: 2),
            Text(
              'Edited',
              style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: (isMine ? cs.onPrimary : cs.onSurface).withValues(
                  alpha: 0.65,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final avatarSlot = SizedBox(
      width: 32,
      child: showAvatar
          ? FurtailNetworkAvatar(
              imageUrl: otherUserAvatarUrl,
              displayName: otherUserName,
              radius: 15, // ~30px diameter, proportional to the bubble
              backgroundColor: cs.primaryContainer,
              foregroundColor: cs.onPrimaryContainer,
            )
          : null,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: groupedWithPrevious ? 2 : 14,
        bottom: 2,
      ),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: isMine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isMine && message.isFailed) ...[
                Icon(Icons.error_outline_rounded, size: 16, color: cs.error),
                const SizedBox(width: 4),
              ],
              if (!isMine) ...[avatarSlot, const SizedBox(width: 6)],
              Flexible(
                child: GestureDetector(
                  onLongPress: isMutating ? null : () => _showActions(context),
                  child: Opacity(opacity: isMutating ? 0.6 : 1, child: bubble),
                ),
              ),
            ],
          ),
          if (isMine && message.isFailed) ...[
            const SizedBox(height: 3),
            Padding(
              padding: EdgeInsets.only(left: isMine ? 0 : 38),
              child: GestureDetector(
                onTap: onRetry,
                child: Text(
                  'Failed · Tap to retry',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else if (isMine && message.isPending) ...[
            const SizedBox(height: 3),
            Padding(
              padding: EdgeInsets.only(left: isMine ? 0 : 38),
              child: Text(
                'Sending…',
                style: TextStyle(fontSize: 11.5, color: context.mutedTextColor),
              ),
            ),
          ] else if (showTimestamp) ...[
            const SizedBox(height: 3),
            Padding(
              padding: EdgeInsets.only(left: isMine ? 0 : 38),
              child: Text(
                formatMessageTimestamp(message.createdAt),
                style: TextStyle(fontSize: 11.5, color: context.mutedTextColor),
              ),
            ),
          ] else
            // Timestamp not shown visually for a mid-group bubble, but kept
            // reachable for screen readers via the bubble's own semantics
            // rather than dropped entirely.
            Semantics(
              label: formatMessageTimestamp(message.createdAt),
              child: const SizedBox.shrink(),
            ),
          if (isMine &&
              showSeenAvatar &&
              !message.isFailed &&
              !message.isPending) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                label: 'Seen by $otherUserName',
                child: FurtailNetworkAvatar(
                  imageUrl: otherUserAvatarUrl,
                  displayName: otherUserName,
                  radius: 8, // ~16dp diameter — subtle, Messenger-scale
                  backgroundColor: cs.primaryContainer,
                  foregroundColor: cs.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTombstone(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: groupedWithPrevious ? 2 : 14,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.block_flipped,
                  size: 14,
                  color: context.mutedTextColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'This message was removed',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: context.mutedTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _BubbleAction { copy, edit, delete }

/// A local image/video/audio preview box, shared by [_UploadingAttachmentTile]
/// and [_FailedAttachmentTile] — an image renders its actual local file
/// (Messenger-style: you see your photo immediately, not a placeholder);
/// video/audio (no cheap local frame to decode here) render a category
/// icon instead. Never a blank/broken box either way.
class _LocalAttachmentPreview extends StatelessWidget {
  const _LocalAttachmentPreview({required this.attachment});
  final MessageAttachmentModel attachment;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final localPath = attachment.localPath;
    if (attachment.isImage && localPath != null) {
      return Image.file(
        File(localPath),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
      );
    }
    return Icon(
      attachment.isVideo
          ? Icons.videocam_outlined
          : attachment.isAudio
          ? Icons.mic_none_outlined
          : Icons.insert_drive_file_outlined,
      color: cs.onSurfaceVariant,
      size: 28,
    );
  }
}

/// Explicit upload-progress states (Part 18) — never an indefinite bare
/// spinner. `Preparing…` covers the brief window before the first
/// `onProgress` tick arrives (progress still 0); once bytes start moving,
/// the real percentage from `AuthenticatedMediaUploader`'s `onSendProgress`
/// is shown.
class _UploadingAttachmentTile extends StatelessWidget {
  const _UploadingAttachmentTile({required this.attachment});
  final MessageAttachmentModel attachment;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final progress = attachment.uploadProgress;
    final label = progress <= 0
        ? 'Preparing…'
        : progress >= 1
        ? 'Sending…'
        : 'Uploading ${(progress * 100).round()}%';
    return Container(
      width: 80,
      height: 80,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _LocalAttachmentPreview(attachment: attachment),
          Container(color: Colors.black.withValues(alpha: 0.45)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress > 0 && progress < 1 ? progress : null,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A failed attachment (Part 20) — keeps whatever local preview is still
/// available, overlays a clear retry affordance, and never shows an
/// indefinite spinner or a blank/broken box.
class _FailedAttachmentTile extends StatelessWidget {
  const _FailedAttachmentTile({required this.attachment, this.onRetry});
  final MessageAttachmentModel attachment;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return GestureDetector(
      onTap: onRetry,
      child: Container(
        width: 80,
        height: 80,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.error.withValues(alpha: 0.6)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _LocalAttachmentPreview(attachment: attachment),
            Container(color: Colors.black.withValues(alpha: 0.5)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  const SizedBox(height: 2),
                  const Text(
                    'Failed · Retry',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
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
