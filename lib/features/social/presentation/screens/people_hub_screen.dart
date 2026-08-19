import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/app/router/app_routes.dart';
import 'package:furtail_app/core/navigation/profile_navigation.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:furtail_app/features/profile/data/models/visitor_profile_model.dart';
import 'package:furtail_app/features/social/data/models/presence_info.dart';
import 'package:furtail_app/features/social/data/models/social_user_summary.dart';
import 'package:furtail_app/features/social/presentation/providers/people_discovery_providers.dart';
import 'package:furtail_app/features/social/presentation/providers/presence_providers.dart';
import 'package:furtail_app/features/social/presentation/providers/social_providers.dart';
import 'package:furtail_app/features/social/presentation/widgets/people_discovery_tile.dart';
import 'package:furtail_app/features/social/presentation/widgets/social_user_tile.dart';

/// Tab indices within [PeopleHubScreen], for deep-linking straight to a
/// specific tab (e.g. the notification "Review Friend Request" CTA jumps
/// straight to Requests instead of landing on Suggestions).
abstract class PeopleHubTab {
  static const suggestions = 0;
  static const requests = 1;
  static const friends = 2;
}

class PeopleHubScreen extends ConsumerStatefulWidget {
  const PeopleHubScreen({
    super.key,
    this.initialTabIndex = PeopleHubTab.suggestions,
  });

  /// Which of the three primary tabs (Suggestions / Requests / Friends) to
  /// open on. See [PeopleHubTab].
  final int initialTabIndex;

  @override
  ConsumerState<PeopleHubScreen> createState() => _PeopleHubScreenState();
}

class _PeopleHubScreenState extends ConsumerState<PeopleHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    (title: 'Suggestions', type: _HubTabType.suggestions),
    (title: 'Requests', type: _HubTabType.requests),
    (title: 'Friends', type: _HubTabType.friends),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _tabs.length - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    // Watch incoming requests to badge the requests tab
    final incomingState = ref.watch(
      socialListProvider(SocialListKind.incoming),
    );
    final incomingCount = incomingState.items.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const _SearchScreen()));
            },
          ),
          PopupMenuButton<SocialListKind>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (kind) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _SecondaryListScreen(kind: kind),
                ),
              );
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: SocialListKind.followers,
                child: Text('Followers'),
              ),
              PopupMenuItem(
                value: SocialListKind.following,
                child: Text('Following'),
              ),
              PopupMenuItem(
                value: SocialListKind.blocked,
                child: Text('Blocked'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,

          // Blue AppBar-এর উপর সব tab text সাদা
          labelColor: cs.onPrimary,
          unselectedLabelColor: cs.onPrimary.withValues(alpha: 0.78),

          // Selected tab-এর নিচের indicator-ও সাদা
          indicatorColor: cs.onPrimary,
          indicatorWeight: 3,

          tabs: [
            const Tab(text: 'Suggestions'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requests'),
                  if (incomingCount > 0 && !incomingState.initialLoading) ...[
                    const SizedBox(width: 6),
                    Badge(
                      label: Text(incomingCount.toString()),

                      // Blue header-এর উপর badge যেন স্পষ্ট দেখা যায়
                      backgroundColor: cs.onPrimary,
                      textColor: cs.primary,
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Friends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DiscoveryTab(kind: PeopleDiscoveryKind.suggestions),
          _RequestsTab(),
          _RelationshipTab(kind: SocialListKind.friends),
        ],
      ),
    );
  }
}

class _SearchScreen extends StatelessWidget {
  const _SearchScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search People'), titleSpacing: 0),
      body: const _DiscoveryTab(kind: PeopleDiscoveryKind.search),
    );
  }
}

class _SecondaryListScreen extends StatelessWidget {
  final SocialListKind kind;
  const _SecondaryListScreen({required this.kind});

  String get _title {
    switch (kind) {
      case SocialListKind.followers:
        return 'Followers';
      case SocialListKind.following:
        return 'Following';
      case SocialListKind.blocked:
        return 'Blocked';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _RelationshipTab(kind: kind),
    );
  }
}

enum _HubTabType { suggestions, requests, friends }

class _DiscoveryTab extends ConsumerStatefulWidget {
  const _DiscoveryTab({required this.kind});
  final PeopleDiscoveryKind kind;

  @override
  ConsumerState<_DiscoveryTab> createState() => _DiscoveryTabState();
}

class _DiscoveryTabState extends ConsumerState<_DiscoveryTab> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

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
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 220;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(peopleDiscoveryProvider(widget.kind).notifier).loadMore();
    }
  }

  /// Debounces remote search so it doesn't fire a network request on every
  /// keystroke — only once typing pauses.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(peopleDiscoveryProvider(widget.kind).notifier).setQuery(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(peopleDiscoveryProvider(widget.kind));
    final controller = ref.read(peopleDiscoveryProvider(widget.kind).notifier);

    ref.listen(peopleDiscoveryProvider(widget.kind), (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    final isSearch = widget.kind == PeopleDiscoveryKind.search;

    if (state.initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (isSearch) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search display name or username',
                  filled: true,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
          if (!isSearch && state.items.isEmpty && !state.refreshing)
            const _EmptyDiscoveryState(
              title: 'You\'re all caught up',
              subtitle:
                  'We\'ll surface people with shared friends, follows, and public activity here.',
            ),
          if (isSearch && state.query.isEmpty)
            const _EmptyDiscoveryState(
              title: 'Search people',
              subtitle:
                  'Type a display name or username to find people on Furtail.',
            ),
          if (isSearch &&
              state.query.isNotEmpty &&
              state.items.isEmpty &&
              !state.initialLoading &&
              !state.refreshing &&
              state.error == null)
            const _EmptyDiscoveryState(
              title: 'No results found',
              subtitle: 'Try searching for another name.',
            ),
          if (state.error != null && state.items.isEmpty)
            _ErrorState(message: state.error!, onRetry: controller.refresh),
          if (state.items.isNotEmpty) ...[
            ...state.items.map(
              (user) => PeopleDiscoveryTile(
                user: user,
                busy: state.pendingActionUserIds.contains(user.id),
                onFriendAction: () => controller.friendAction(user),
                onFollowAction: () => controller.follow(user),
                onDismiss: () => controller.dismiss(user),
              ),
            ),
          ],
          if (state.loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RelationshipTab extends ConsumerStatefulWidget {
  const _RelationshipTab({required this.kind});
  final SocialListKind kind;

  @override
  ConsumerState<_RelationshipTab> createState() => _RelationshipTabState();
}

class _RelationshipTabState extends ConsumerState<_RelationshipTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 220;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(socialListProvider(widget.kind).notifier).loadMore();
    }
  }

  List<int>? _presenceFetchedFor;

  void _maybeFetchPresence(List<SocialUserSummary> items) {
    if (widget.kind != SocialListKind.friends) return;
    final ids = items.map((u) => u.id).toList();
    if (ids.isEmpty || _listEquals(ids, _presenceFetchedFor)) return;
    _presenceFetchedFor = ids;
    scheduleMicrotask(
      () => ref.read(presenceCacheProvider.notifier).fetchAll(ids),
    );
  }

  bool _listEquals(List<int> a, List<int>? b) {
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(socialListProvider(widget.kind));
    final controller = ref.read(socialListProvider(widget.kind).notifier);
    final Map<int, PresenceInfo> presenceByUser =
        widget.kind == SocialListKind.friends
        ? ref.watch(presenceCacheProvider)
        : const {};

    if (state.initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    _maybeFetchPresence(state.items);

    if (state.items.isEmpty) {
      return _RelationshipEmptyState(
        kind: widget.kind,
        onRefresh: controller.refresh,
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount:
            state.items.length +
            (state.hasMore ? 1 : 0) +
            (widget.kind == SocialListKind.friends ? 1 : 0),
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 84),
        itemBuilder: (context, index) {
          if (widget.kind == SocialListKind.friends && index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Your friends · ${state.items.length}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.onSurface,
                ),
              ),
            );
          }

          final itemIndex = widget.kind == SocialListKind.friends
              ? index - 1
              : index;

          if (itemIndex >= state.items.length) {
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
          final row = state.items[itemIndex];
          final busy = state.pendingActionUserIds.contains(row.id);
          return _relationshipTile(
            context,
            row,
            controller,
            busy,
            presenceByUser[row.id],
          );
        },
      ),
    );
  }

  Future<void> _openConversation(
    BuildContext context,
    SocialUserSummary user,
  ) async {
    try {
      final conversationId = await ref
          .read(messagingRepositoryProvider)
          .startConversation(user.id);
      if (!context.mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.messagesChat,
        arguments: {
          'conversationId': conversationId,
          'otherUserId': user.id,
          'otherUserName': user.displayName,
          'otherUserAvatarUrl': user.avatarUrl,
        },
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this conversation. Please try again.'),
        ),
      );
    }
  }

  Future<void> _confirmUnfriend(
    BuildContext context,
    SocialListController controller,
    SocialUserSummary row,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text(
          '${row.displayName} will be removed from your friends list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) controller.unfriend(row);
  }

  Widget _relationshipTile(
    BuildContext context,
    SocialUserSummary row,
    SocialListController controller,
    bool busy,
    PresenceInfo? presence,
  ) {
    switch (widget.kind) {
      case SocialListKind.friends:
        return SocialUserTile(
          user: row,
          busy: busy,
          avatarRadius: 30,
          presence: presence,
          trailing: _FriendRowActions(
            onMessage: () => _openConversation(context, row),
            onViewProfile: () => ProfileNavigation.openUserProfile(
              context,
              row.id,
              preview: VisitorProfilePreview(
                id: row.id,
                displayName: row.displayName,
                username: row.username,
                avatarUrl: row.avatarUrl,
              ),
            ),
            onRemove: () => _confirmUnfriend(context, controller, row),
          ),
        );
      case SocialListKind.followers:
        return SocialUserTile(user: row, busy: busy);
      case SocialListKind.following:
        return SocialUserTile(
          user: row,
          busy: busy,
          primaryLabel: 'Unfollow',
          onPrimary: () => controller.unfollow(row),
        );
      case SocialListKind.blocked:
        return SocialUserTile(
          user: row,
          busy: busy,
          primaryLabel: 'Unblock',
          onPrimary: () => controller.unblock(row),
        );
      case SocialListKind.incoming:
        return SocialUserTile(
          user: row,
          busy: busy,
          primaryLabel: 'Accept',
          onPrimary: () => controller.acceptIncoming(row),
          secondaryLabel: 'Decline',
          onSecondary: () => controller.declineIncoming(row),
        );
      case SocialListKind.outgoing:
        return SocialUserTile(
          user: row,
          busy: busy,
          primaryLabel: 'Cancel',
          onPrimary: () => controller.cancelOutgoing(row),
        );
    }
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            isScrollable: false,
            labelPadding: EdgeInsets.zero,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Incoming'),
              Tab(text: 'Sent'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _RelationshipTab(kind: SocialListKind.incoming),
                _RelationshipTab(kind: SocialListKind.outgoing),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDiscoveryState extends StatelessWidget {
  const _EmptyDiscoveryState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: context.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedTextColor),
          ),
        ],
      ),
    );
  }
}

class _RelationshipEmptyState extends StatelessWidget {
  const _RelationshipEmptyState({required this.kind, required this.onRefresh});
  final SocialListKind kind;
  final Future<void> Function() onRefresh;

  (String, String) get _copy {
    switch (kind) {
      case SocialListKind.friends:
        return ('No friends yet', 'Find people you know and start connecting.');
      case SocialListKind.incoming:
        return (
          'No friend requests',
          'Requests you receive will show up here.',
        );
      case SocialListKind.outgoing:
        return (
          'No pending requests',
          'Requests you\'ve sent will show up here.',
        );
      case SocialListKind.followers:
        return ('No followers yet', '');
      case SocialListKind.following:
        return ('You\'re not following anyone yet', '');
      case SocialListKind.blocked:
        return ('You haven\'t blocked anyone', '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _copy;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.45,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 56,
                      color: context.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.mutedTextColor),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: context.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Compact trailing actions for a Friends-list row: a single Message icon
/// button plus a "More" overflow menu (View profile / Message / Remove
/// friend). Keeps Remove Friend out of the row's default visual weight —
/// it's a confirmed, deliberate action inside the menu, not a large red
/// button competing with every other row.
class _FriendRowActions extends StatelessWidget {
  const _FriendRowActions({
    required this.onMessage,
    required this.onViewProfile,
    required this.onRemove,
  });

  final VoidCallback onMessage;
  final VoidCallback onViewProfile;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onMessage,
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          tooltip: 'Message',
          color: context.colorScheme.primary,
          style: IconButton.styleFrom(
            backgroundColor: context.colorScheme.primaryContainer,
          ),
        ),
        PopupMenuButton<_FriendRowAction>(
          icon: const Icon(Icons.more_vert_rounded),
          tooltip: 'More',
          onSelected: (action) {
            switch (action) {
              case _FriendRowAction.viewProfile:
                onViewProfile();
              case _FriendRowAction.message:
                onMessage();
              case _FriendRowAction.remove:
                onRemove();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _FriendRowAction.viewProfile,
              child: Text('View profile'),
            ),
            PopupMenuItem(
              value: _FriendRowAction.message,
              child: Text('Message'),
            ),
            PopupMenuItem(
              value: _FriendRowAction.remove,
              child: Text('Remove friend'),
            ),
          ],
        ),
      ],
    );
  }
}

enum _FriendRowAction { viewProfile, message, remove }
