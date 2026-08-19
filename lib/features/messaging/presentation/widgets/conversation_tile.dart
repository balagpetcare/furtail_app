import 'package:flutter/material.dart';

import 'package:furtail_app/core/media/media_url.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:furtail_app/features/social/presentation/widgets/presence_dot.dart';

import '../../data/models/conversation_model.dart';

String formatMessageTimestamp(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d';
  final sameYear = dt.year == now.year;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final label = '${months[dt.month - 1]} ${dt.day}';
  return sameYear ? label : '$label, ${dt.year}';
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.isOnline = false,
  });

  final ConversationModel conversation;
  final VoidCallback onTap;

  /// Whether [conversation.otherUser] is currently active, per the shared
  /// presence cache — left false (no dot) when unknown/private, never
  /// fabricated.
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final other = conversation.otherUser;
    final name = other?.displayName ?? 'Furtail Member';
    final avatarUrl = other?.avatarUrl;
    final last = conversation.lastMessage;
    final unread = conversation.unreadCount;
    final hasUnread = unread > 0;
    final previewText = last == null
        ? 'Say hello 👋'
        : last.isDeleted
        ? 'This message was removed'
        : last.body;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                FurtailNetworkAvatar(
                  imageUrl:
                      other?.resolvedAvatarUrl(MediaUse.thumbnail) ?? avatarUrl,
                  displayName: name,
                  radius: 28,
                  backgroundColor: cs.primaryContainer,
                  foregroundColor: cs.onPrimaryContainer,
                ),
                if (isOnline)
                  const Positioned(
                    right: -1,
                    bottom: -1,
                    child: PresenceDot(isOnline: true, diameter: 14),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: hasUnread
                                ? FontWeight.w800
                                : FontWeight.w700,
                            fontSize: 15,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      if (conversation.lastMessageAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          formatMessageTimestamp(conversation.lastMessageAt!),
                          style: TextStyle(
                            fontSize: 12,
                            color: hasUnread
                                ? cs.primary
                                : context.mutedTextColor,
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          previewText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontStyle: (last?.isDeleted ?? false)
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: hasUnread
                                ? cs.onSurface
                                : context.mutedTextColor,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(
                          count: unread,
                          color: cs.primary,
                          onColor: cs.onPrimary,
                        ),
                      ],
                    ],
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

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({
    required this.count,
    required this.color,
    required this.onColor,
  });
  final int count;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: onColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
