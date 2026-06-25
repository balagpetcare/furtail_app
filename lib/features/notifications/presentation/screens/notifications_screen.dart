import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/core/deep_link/deep_link_provider.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';

import '../../data/models/notification_item.dart';
import '../../domain/notification_type.dart';
import '../providers/notification_controller.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsListProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationsListProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(notificationsListProvider.notifier).load();
  }

  void _onTapItem(NotificationItem item) {
    // Mark as read optimistically.
    if (!item.isRead) {
      ref.read(notificationsListProvider.notifier).markAsRead(item.id);
    }

    final url = item.actionUrl;
    if (url != null && url.isNotEmpty) {
      ref.read(deepLinkServiceProvider).handleString(url);
      return;
    }

    // Fallback navigation by type.
    final deepLink = ref.read(deepLinkServiceProvider);
    switch (item.type) {
      case AppNotificationType.friendRequestReceived:
      case AppNotificationType.friendRequestAccepted:
      case AppNotificationType.userFollowed:
        if (item.actorId != null) {
          deepLink.handleString('/profile/${item.actorId}');
        }
        break;
      case AppNotificationType.petFollowed:
      case AppNotificationType.petLiked:
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsListProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: Navigator.canPop(context)
            ? const BackButton()
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        actions: [
          if (state.items.any((n) => !n.isRead))
            TextButton(
              onPressed: () {
                ref.read(notificationsListProvider.notifier).markAllAsRead();
              },
              child: Text(
                'Mark all read',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
        ],
      ),
      body: _buildBody(state, theme, colorScheme),
    );
  }

  Widget _buildBody(
    NotificationsListState state,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty && state.error == null) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Social activity will appear here',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: colorScheme.error),
            const SizedBox(height: 12),
            Text('Could not load notifications', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _onRefresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
            );
          }
          return _NotificationTile(
            item: state.items[index],
            onTap: () => _onTapItem(state.items[index]),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.day}/${date.month}/${date.year}';
  }

  IconData _typeIcon(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.friendRequestReceived:
      case AppNotificationType.friendRequestAccepted:
        return Icons.person_add_rounded;
      case AppNotificationType.userFollowed:
        return Icons.person_outline_rounded;
      case AppNotificationType.petFollowed:
        return Icons.pets_rounded;
      case AppNotificationType.petLiked:
        return Icons.favorite_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUnread = !item.isRead;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUnread
              ? colorScheme.primary.withValues(alpha: 0.04)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar.
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: FurtailNetworkAvatar(
                imageUrl: item.actorAvatarUrl,
                displayName: item.actorName ?? '?',
                radius: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Content.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + unread dot + time.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isUnread)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 6),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(item.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (item.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Type icon.
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Icon(
                _typeIcon(item.type),
                size: 18,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
