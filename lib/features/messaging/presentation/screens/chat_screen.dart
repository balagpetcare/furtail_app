import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/core/navigation/profile_navigation.dart';
import 'package:furtail_app/core/network/connectivity_service.dart';
import 'package:furtail_app/core/providers/current_user_provider.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:furtail_app/features/social/presentation/providers/presence_providers.dart';
import 'package:furtail_app/features/social/presentation/providers/social_providers.dart';
import 'package:furtail_app/features/social/presentation/widgets/presence_dot.dart';

import '../../data/messaging_service.dart' show MessagingMediaSettings;
import '../../data/models/message_model.dart';
import '../providers/message_notification_coordinator.dart';
import '../providers/messaging_providers.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_composer.dart';

/// A single 1:1 conversation thread — text-only, per this feature's scope
/// (no attachments/reactions/typing indicators/presence). Audio/video call
/// entry points are visible but intentionally not implemented yet (see
/// [_showComingSoon]).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    this.otherUserName,
    this.otherUserAvatarUrl,
  });

  final int conversationId;
  final int otherUserId;
  final String? otherUserName;
  final String? otherUserAvatarUrl;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  ConnectivityStatus? _lastConnectivity;

  /// The message currently being edited in the composer, or null for a
  /// normal new-message compose.
  MessageModel? _editingMessage;

  ThreadKey get _key =>
      (conversationId: widget.conversationId, otherUserId: widget.otherUserId);

  // Captured in initState — `ref` is not usable from dispose() once the
  // element starts unmounting, so the reference this cleanup needs has to
  // be grabbed while `ref` is still live (same pattern as
  // MessageThreadController's own onDispose cleanup).
  late final MessageNotificationCoordinator _notificationCoordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_maybeLoadOlder);
    // Marks this conversation as "currently visible" so the FCM foreground
    // handler (NotificationController) can suppress an intrusive system
    // notification banner for a message the realtime bubble already shows.
    _notificationCoordinator = ref.read(messageNotificationCoordinatorProvider);
    _notificationCoordinator.setActiveConversation(widget.conversationId);
    Future.microtask(
      () => ref.read(presenceCacheProvider.notifier).fetchAll([
        widget.otherUserId,
      ]),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_maybeLoadOlder);
    _scrollController.dispose();
    _notificationCoordinator.clearActiveConversation(widget.conversationId);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(messageThreadProvider(_key).notifier);
    if (state == AppLifecycleState.resumed) {
      notifier.setForeground(true);
      notifier.reconcile();
      ref.read(presenceCacheProvider.notifier).fetchAll([widget.otherUserId]);
    } else {
      // Backgrounded/inactive — this device is no longer meaningfully
      // "typing" from the recipient's perspective; stop immediately rather
      // than leaving the recipient's expiry timer to clear it a few
      // seconds late. Also stop advancing the read marker for any message
      // that arrives while backgrounded — a message only counts as
      // actually viewed while this screen is genuinely visible.
      notifier.stopTypingForBackground();
      notifier.setForeground(false);
    }
  }

  void _maybeLoadOlder() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(messageThreadProvider(_key).notifier).loadOlder();
    }
  }

  void _showComingSoon(String feature) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                feature == 'Video calling'
                    ? Icons.videocam_rounded
                    : Icons.call_rounded,
                size: 40,
                color: context.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '$feature is coming soon',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'We\'re working on secure calling for Furtail.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.mutedTextColor),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleBlock() async {
    final name = widget.otherUserName ?? 'this user';
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Block user?'),
            content: Text(
              'You will no longer see messages from $name and they '
              "won't be able to message you.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Block'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    try {
      await ref.read(socialRepositoryProvider).block(widget.otherUserId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not block this user right now.')),
      );
    }
  }

  void _startEdit(MessageModel message) {
    setState(() => _editingMessage = message);
  }

  void _cancelEdit() {
    setState(() => _editingMessage = null);
  }

  Future<void> _submitEditOrSend(String text, List<File> attachments) async {
    final editing = _editingMessage;
    if (editing == null) {
      ref
          .read(messageThreadProvider(_key).notifier)
          .send(text, attachments: attachments);
      return;
    }
    setState(() => _editingMessage = null);
    if (text.trim() == editing.body && attachments.isEmpty) {
      return; // no real change — just exit
    }
    final ok = await ref
        .read(messageThreadProvider(_key).notifier)
        .editMessage(editing, text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your edit. Try again.')),
      );
    }
  }

  Future<void> _confirmDelete(MessageModel message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsend this message?'),
        content: const Text(
          'This message will be removed for both of you. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unsend'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final success = await ref
        .read(messageThreadProvider(_key).notifier)
        .deleteMessage(message);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not unsend this message.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reconcile from REST whenever connectivity comes back online — a
    // dropped realtime stream during an outage never permanently loses a
    // message, only delays how quickly it shows up.
    ref.listen(connectivityStatusProvider, (previous, next) {
      final status = next.asData?.value;
      if (status == ConnectivityStatus.online &&
          _lastConnectivity != ConnectivityStatus.online) {
        ref.read(messageThreadProvider(_key).notifier).reconcile();
      }
      _lastConnectivity = status;
    });

    final state = ref.watch(messageThreadProvider(_key));
    final controller = ref.read(messageThreadProvider(_key).notifier);

    ref.listen(messageThreadProvider(_key), (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    final presence = ref.watch(presenceCacheProvider)[widget.otherUserId];
    final isOnline = presence?.isOnline ?? false;
    final isTyping = state.remoteTyping && isOnline;
    final statusLabel = isTyping ? 'Typing…' : presence?.statusLabel;
    final mediaSettings =
        ref.watch(messagingMediaSettingsProvider).valueOrNull ??
        MessagingMediaSettings.fallback;

    // Fallback to white if no AppBar foreground color is specified,
    // ensuring contrast on the blue primary header.
    final appBarFg =
        Theme.of(context).appBarTheme.foregroundColor ?? Colors.white;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () =>
              ProfileNavigation.openUserProfile(context, widget.otherUserId),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  FurtailNetworkAvatar(
                    imageUrl: widget.otherUserAvatarUrl,
                    displayName: widget.otherUserName ?? 'Furtail Member',
                    radius: 20,
                  ),
                  if (isOnline)
                    const Positioned(
                      right: -1,
                      bottom: -1,
                      child: PresenceDot(isOnline: true, diameter: 12),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.otherUserName ?? 'Furtail Member',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: appBarFg,
                      ),
                    ),
                    if (statusLabel != null)
                      Text(
                        statusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline
                              ? appBarFg
                              : appBarFg.withValues(alpha: 0.8),
                          fontWeight: isOnline
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            tooltip: 'Audio call',
            onPressed: () => _showComingSoon('Audio calling'),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Video call',
            onPressed: () => _showComingSoon('Video calling'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  ProfileNavigation.openUserProfile(
                    context,
                    widget.otherUserId,
                  );
                case 'block':
                  _handleBlock();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('View profile')),
              PopupMenuItem(value: 'block', child: Text('Block')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _messageList(state, controller)),
            if (!state.initialLoading)
              MessageComposer(
                onSend: _submitEditOrSend,
                onTextChanged: controller.onComposerTextChanged,
                disabledReason: state.checkingEligibility
                    ? null
                    : state.disabledReason,
                editingMessage: _editingMessage,
                onCancelEdit: _cancelEdit,
                mediaSettings: mediaSettings,
              ),
          ],
        ),
      ),
    );
  }

  Widget _messageList(ThreadState state, MessageThreadController controller) {
    if (state.initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.messages.isEmpty) {
      if (state.error != null) {
        return _RetryView(message: state.error!, onRetry: controller.reconcile);
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No messages yet. Say hello 👋',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedTextColor),
          ),
        ),
      );
    }

    final myId = ref.watch(currentUserProvider).userId;
    final latestSeenOwnMessageId = myId != null
        ? state.latestSeenOwnMessageId(myId)
        : null;

    // Messages are newest-first (reverse ListView). "Previous" in
    // conversation order is index + 1, "next" is index - 1.
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: state.messages.length + (state.hasMoreOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final message = state.messages[index];
        final isMine = message.senderId == myId;
        final older = index + 1 < state.messages.length
            ? state.messages[index + 1]
            : null;
        final newer = index > 0 ? state.messages[index - 1] : null;

        final sameSenderAsOlder =
            older != null && older.senderId == message.senderId;
        final sameSenderAsNewer =
            newer != null && newer.senderId == message.senderId;
        final showDateSeparator =
            older == null || !_isSameDay(older.createdAt, message.createdAt);
        // Show the avatar on the last bubble of a consecutive incoming
        // group (i.e. when the next-newer message is from someone else),
        // not beside every single bubble.
        final showAvatar = !isMine && !sameSenderAsNewer;

        return Column(
          key: ValueKey(
            message.id != null
                ? 'id:${message.id}'
                : 'cid:${message.clientMessageId}',
          ),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDateSeparator) _DateSeparator(date: message.createdAt),
            MessageBubble(
              message: message,
              isMine: isMine,
              showAvatar: showAvatar,
              groupedWithPrevious: sameSenderAsOlder && !showDateSeparator,
              // Only the last (most recent) bubble of a consecutive
              // same-sender run shows its timestamp — matches modern
              // messenger grouping instead of a caption under every bubble.
              showTimestamp: !sameSenderAsNewer,
              onRetry: isMine && message.isFailed
                  ? () => controller.retry(message)
                  : null,
              onEdit: isMine && message.isSent && !message.isDeleted
                  ? () => _startEdit(message)
                  : null,
              onDelete: isMine && message.isSent && !message.isDeleted
                  ? () => _confirmDelete(message)
                  : null,
              isMutating:
                  message.id != null && controller.isMutating(message.id!),
              otherUserAvatarUrl: widget.otherUserAvatarUrl,
              otherUserName: widget.otherUserName ?? 'Furtail Member',
              showSeenAvatar:
                  message.id != null && message.id == latestSeenOwnMessageId,
            ),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});
  final DateTime date;

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
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
    final label = '${months[date.month - 1]} ${date.day}';
    return date.year == now.year ? label : '$label, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.mutedTextColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryView extends StatelessWidget {
  const _RetryView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
