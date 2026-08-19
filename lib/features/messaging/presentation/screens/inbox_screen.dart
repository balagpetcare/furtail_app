import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/app/router/app_routes.dart';
import 'package:furtail_app/core/media/media_url.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';

import 'package:furtail_app/features/social/presentation/providers/presence_providers.dart';

import '../../data/models/conversation_model.dart';
import '../providers/messaging_providers.dart';
import '../widgets/conversation_tile.dart';

/// The Messages inbox: every conversation the current user participates
/// in, ordered by latest activity (see `ConversationsListController`).
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchController.clear();
      }
    });
  }

  /// Filters the conversations already loaded on the client. The Inbox is
  /// paginated (see `ConversationsListController`/`hasMore`), so this only
  /// searches conversations fetched so far — there is no backend search
  /// endpoint for conversations to query the full list remotely.
  List<ConversationModel> _filtered(List<ConversationModel> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where((c) {
          final name = c.otherUser?.displayName.toLowerCase() ?? '';
          final username = c.otherUser?.username?.toLowerCase() ?? '';
          return name.contains(q) || username.contains(q);
        })
        .toList(growable: false);
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(conversationsListProvider.notifier).loadMore();
    }
  }

  void _openConversation(
    int conversationId,
    int otherUserId,
    String? name,
    String? avatarUrl,
  ) {
    Navigator.pushNamed(
      context,
      AppRoutes.messagesChat,
      arguments: {
        'conversationId': conversationId,
        'otherUserId': otherUserId,
        'otherUserName': name,
        'otherUserAvatarUrl': avatarUrl,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsListProvider);
    final controller = ref.read(conversationsListProvider.notifier);

    ref.listen(conversationsListProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search conversations',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('Messages'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _searching ? 'Close search' : 'Search conversations',
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: SafeArea(child: _body(state, controller)),
    );
  }

  List<int>? _presenceFetchedFor;

  void _maybeFetchPresence(List<ConversationModel> items) {
    final ids = items.map((c) => c.otherUserId).toList();
    if (ids.isEmpty) return;
    final prev = _presenceFetchedFor;
    if (prev != null && prev.length == ids.length && prev.every(ids.contains)) {
      return;
    }
    _presenceFetchedFor = ids;
    Future.microtask(
      () => ref.read(presenceCacheProvider.notifier).fetchAll(ids),
    );
  }

  Widget _body(InboxState state, ConversationsListController controller) {
    if (state.initialLoading) {
      return const _InboxLoadingSkeleton();
    }

    if (state.items.isEmpty) {
      if (state.error != null) {
        return _RetryView(message: state.error!, onRetry: controller.refresh);
      }
      return _EmptyInbox(onRefresh: controller.refresh);
    }

    final visible = _filtered(state.items);
    if (_searching && _query.isNotEmpty && visible.isEmpty) {
      return _NoSearchResults(query: _query);
    }

    // Pagination only applies to the unfiltered list — while actively
    // searching, "load more" would silently fetch conversations that don't
    // match the query, so it's suppressed until search is cleared.
    //
    // Gated on `loadingMore`, not merely `hasMore`: `hasMore` just means
    // "there is another page available whenever the user scrolls further,"
    // which is normal, idle pagination state — showing a spinner for that
    // (rather than only while a fetch is actually in flight) left a
    // permanent-looking stray loading row at the bottom of an otherwise
    // fully-loaded inbox.
    final showLoadMoreTail = !_searching && state.loadingMore;
    _maybeFetchPresence(visible);
    final presenceByUser = ref.watch(presenceCacheProvider);

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visible.length + (showLoadMoreTail ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 84),
        itemBuilder: (context, index) {
          if (index >= visible.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final conversation = visible[index];
          return ConversationTile(
            key: ValueKey(conversation.conversationId),
            conversation: conversation,
            isOnline:
                presenceByUser[conversation.otherUserId]?.isOnline ?? false,
            onTap: () => _openConversation(
              conversation.conversationId,
              conversation.otherUserId,
              conversation.otherUser?.displayName,
              conversation.otherUser?.resolvedAvatarUrl(MediaUse.thumbnail),
            ),
          );
        },
      ),
    );
  }
}

class _InboxLoadingSkeleton extends StatelessWidget {
  const _InboxLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 8,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 84),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: cs.surfaceContainerHighest,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 14,
                    width: 140,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
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

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 44,
              color: context.mutedTextColor,
            ),
            const SizedBox(height: 12),
            Text(
              'No conversations found',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: context.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No results for "$query" in your loaded conversations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedTextColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 48,
                        color: context.mutedTextColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Message an accepted friend to start a conversation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.mutedTextColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
            Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: context.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Couldn\'t load your messages',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: context.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedTextColor),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
