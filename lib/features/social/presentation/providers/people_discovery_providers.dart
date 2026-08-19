import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/services/api_client.dart';
import 'package:furtail_app/services/social_service.dart';
import 'package:furtail_app/features/social/data/models/people_discovery_user.dart';
import 'package:furtail_app/features/social/data/social_repository.dart';

enum PeopleDiscoveryKind { suggestions, search }

class PeopleDiscoveryState {
  final List<PeopleDiscoveryUser> items;
  final bool initialLoading;
  final bool refreshing;
  final bool loadingMore;
  final String? error;
  final String? nextCursor;
  final bool hasMore;
  final String query;
  final Set<int> pendingActionUserIds;

  const PeopleDiscoveryState({
    required this.items,
    required this.initialLoading,
    required this.refreshing,
    required this.loadingMore,
    required this.error,
    required this.nextCursor,
    required this.hasMore,
    required this.query,
    required this.pendingActionUserIds,
  });

  factory PeopleDiscoveryState.initial({String query = ''}) =>
      PeopleDiscoveryState(
        items: const [],
        initialLoading: true,
        refreshing: false,
        loadingMore: false,
        error: null,
        nextCursor: null,
        hasMore: false,
        query: query,
        pendingActionUserIds: const {},
      );

  PeopleDiscoveryState copyWith({
    List<PeopleDiscoveryUser>? items,
    bool? initialLoading,
    bool? refreshing,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    String? query,
    Set<int>? pendingActionUserIds,
  }) {
    return PeopleDiscoveryState(
      items: items ?? this.items,
      initialLoading: initialLoading ?? this.initialLoading,
      refreshing: refreshing ?? this.refreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      query: query ?? this.query,
      pendingActionUserIds: pendingActionUserIds ?? this.pendingActionUserIds,
    );
  }
}

final peopleDiscoveryRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(
    service: SocialService(client: ref.watch(apiClientProvider)),
  ),
);

final peopleDiscoveryProvider =
    AutoDisposeNotifierProviderFamily<
      PeopleDiscoveryController,
      PeopleDiscoveryState,
      PeopleDiscoveryKind
    >(PeopleDiscoveryController.new);

class PeopleDiscoveryController
    extends
        AutoDisposeFamilyNotifier<PeopleDiscoveryState, PeopleDiscoveryKind> {
  late PeopleDiscoveryKind _kind;

  @override
  PeopleDiscoveryState build(PeopleDiscoveryKind kind) {
    _kind = kind;
    scheduleMicrotask(refresh);
    return PeopleDiscoveryState.initial();
  }

  SocialRepository get _repo => ref.read(peopleDiscoveryRepositoryProvider);

  String _friendlyError(Object e) {
    if (e is Exception) return e.toString().replaceAll('Exception: ', '');
    return 'Something went wrong';
  }

  Future<DiscoveryListResult> _fetchPage({String? cursor}) {
    switch (_kind) {
      case PeopleDiscoveryKind.suggestions:
        return _repo.suggestions(cursor: cursor);
      case PeopleDiscoveryKind.search:
        return _repo.search(query: state.query, cursor: cursor);
    }
  }

  Future<void> refresh() async {
    final hadItems = state.items.isNotEmpty;
    state = state.copyWith(
      initialLoading: !hadItems,
      refreshing: hadItems,
      clearError: true,
    );
    if (_kind == PeopleDiscoveryKind.search && state.query.isEmpty) {
      state = state.copyWith(
        items: const [],
        initialLoading: false,
        refreshing: false,
        hasMore: false,
        clearNextCursor: true,
      );
      return;
    }
    try {
      final result = await _fetchPage();
      state = state.copyWith(
        items: result.items,
        nextCursor: result.nextCursor,
        clearNextCursor: result.nextCursor == null,
        hasMore: result.hasMore,
        initialLoading: false,
        refreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        initialLoading: false,
        refreshing: false,
        error: _friendlyError(e),
      );
    }
  }

  Future<void> setQuery(String query) async {
    if (_kind != PeopleDiscoveryKind.search) return;
    final next = query.trim();
    if (next == state.query) return;
    state = state.copyWith(
      query: next,
      clearError: true,
      clearNextCursor: true,
    );
    if (next.isEmpty) {
      state = state.copyWith(
        items: const [],
        initialLoading: false,
        refreshing: false,
        hasMore: false,
      );
      return;
    }
    await refresh();
  }

  Future<void> loadMore() async {
    if (state.loadingMore ||
        state.refreshing ||
        !state.hasMore ||
        state.nextCursor == null) {
      return;
    }
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final result = await _fetchPage(cursor: state.nextCursor);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        nextCursor: result.nextCursor,
        clearNextCursor: result.nextCursor == null,
        hasMore: result.hasMore,
        loadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: _friendlyError(e));
    }
  }

  bool _beginAction(int userId) {
    if (state.pendingActionUserIds.contains(userId)) return false;
    state = state.copyWith(
      pendingActionUserIds: {...state.pendingActionUserIds, userId},
    );
    return true;
  }

  void _endAction(int userId) {
    final next = {...state.pendingActionUserIds}..remove(userId);
    state = state.copyWith(pendingActionUserIds: next);
  }

  void _updateItem(
    int userId,
    PeopleDiscoveryUser Function(PeopleDiscoveryUser item) update,
  ) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.id == userId) update(item) else item,
      ],
    );
  }

  Future<void> _runAction(
    int userId,
    Future<void> Function() action, {
    PeopleDiscoveryUser Function(PeopleDiscoveryUser item)? optimisticUpdate,
  }) async {
    if (!_beginAction(userId)) return;
    if (optimisticUpdate != null) {
      _updateItem(userId, optimisticUpdate);
    }
    try {
      await action();
      await refresh();
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      await refresh();
    } finally {
      _endAction(userId);
    }
  }

  Future<void> follow(PeopleDiscoveryUser user) => _runAction(
    user.id,
    () => user.isFollowing ? _repo.unfollow(user.id) : _repo.follow(user.id),
    optimisticUpdate: (item) => item.copyWith(isFollowing: !item.isFollowing),
  );

  Future<void> friendAction(PeopleDiscoveryUser user) async {
    if (user.hasIncomingRequest) {
      return acceptRequest(user);
    }
    if (user.hasOutgoingRequest) {
      return cancelRequest(user);
    }
    if (user.isFriend) return unfriend(user);
    return sendFriendRequest(user);
  }

  Future<void> sendFriendRequest(PeopleDiscoveryUser user) => _runAction(
    user.id,
    () async {
      final requestId = await _repo.sendFriendRequest(user.id);
      if (requestId == null) {
        return;
      }
      _updateItem(
        user.id,
        (item) => item.copyWith(
          friendRequestState: 'OUTGOING_PENDING',
          friendRequestId: requestId,
        ),
      );
    },
    optimisticUpdate: (item) => item.copyWith(
      friendRequestState: 'OUTGOING_PENDING',
      friendRequestId: item.friendRequestId,
    ),
  );

  Future<void> acceptRequest(PeopleDiscoveryUser user) => _runAction(
    user.id,
    () async {
      final requestId = user.friendRequestId;
      if (requestId == null) return;
      await _repo.acceptRequest(requestId);
    },
    optimisticUpdate: (item) => item.copyWith(
      isFriend: true,
      friendRequestState: 'NONE',
      friendRequestId: null,
    ),
  );

  Future<void> cancelRequest(PeopleDiscoveryUser user) => _runAction(
    user.id,
    () async {
      final requestId = user.friendRequestId;
      if (requestId == null) return;
      await _repo.cancelRequest(requestId);
    },
    optimisticUpdate: (item) =>
        item.copyWith(friendRequestState: 'NONE', friendRequestId: null),
  );

  Future<void> unfriend(PeopleDiscoveryUser user) => _runAction(
    user.id,
    () => _repo.unfriend(user.id),
    optimisticUpdate: (item) => item.copyWith(isFriend: false),
  );

  Future<void> dismiss(PeopleDiscoveryUser user) async {
    if (!_beginAction(user.id)) return;
    final originalItems = state.items;
    state = state.copyWith(
      items: state.items.where((item) => item.id != user.id).toList(),
      clearError: true,
    );
    try {
      await _repo.dismissSuggestion(user.id);
      await refresh();
    } catch (e) {
      state = state.copyWith(items: originalItems, error: _friendlyError(e));
      await refresh();
    } finally {
      _endAction(user.id);
    }
  }
}
