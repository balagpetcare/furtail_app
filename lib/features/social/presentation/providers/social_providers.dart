import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/services/api_client.dart';
import 'package:furtail_app/services/social_service.dart';
import 'package:furtail_app/features/social/presentation/providers/people_discovery_providers.dart';

import '../../data/models/social_user_summary.dart';
import '../../data/social_repository.dart';

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(
    service: SocialService(client: ref.watch(apiClientProvider)),
  ),
);

/// Which Social hub tab a [SocialListController] instance backs. Kept as a
/// single generic controller (rather than six near-identical Notifiers)
/// since loading/pagination/rapid-tap-guard logic is identical across tabs
/// — only which repository call to make, and which action button a row
/// gets, differ.
enum SocialListKind {
  friends,
  incoming,
  outgoing,
  followers,
  following,
  blocked,
}

class SocialListState {
  final List<SocialUserSummary> items;
  final bool initialLoading;
  final bool refreshing;
  final bool loadingMore;
  final String? error;
  final String? nextCursor;
  final bool hasMore;

  /// User ids with an in-flight row action (accept/decline/cancel/unfriend/
  /// unfollow/unblock) — both drives the row's inline spinner and blocks a
  /// second tap on the same row from firing a duplicate request.
  final Set<int> pendingActionUserIds;

  const SocialListState({
    required this.items,
    required this.initialLoading,
    required this.refreshing,
    required this.loadingMore,
    required this.error,
    required this.nextCursor,
    required this.hasMore,
    required this.pendingActionUserIds,
  });

  factory SocialListState.initial() => const SocialListState(
    items: [],
    initialLoading: true,
    refreshing: false,
    loadingMore: false,
    error: null,
    nextCursor: null,
    hasMore: false,
    pendingActionUserIds: {},
  );

  SocialListState copyWith({
    List<SocialUserSummary>? items,
    bool? initialLoading,
    bool? refreshing,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    Set<int>? pendingActionUserIds,
  }) {
    return SocialListState(
      items: items ?? this.items,
      initialLoading: initialLoading ?? this.initialLoading,
      refreshing: refreshing ?? this.refreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      pendingActionUserIds: pendingActionUserIds ?? this.pendingActionUserIds,
    );
  }
}

final socialListProvider =
    AutoDisposeNotifierProviderFamily<
      SocialListController,
      SocialListState,
      SocialListKind
    >(SocialListController.new);

class SocialListController
    extends AutoDisposeFamilyNotifier<SocialListState, SocialListKind> {
  late final SocialListKind _kind;

  @override
  SocialListState build(SocialListKind kind) {
    _kind = kind;
    scheduleMicrotask(refresh);
    return SocialListState.initial();
  }

  SocialRepository get _repo => ref.read(socialRepositoryProvider);

  void _refreshSuggestionFeed() {
    ref.invalidate(peopleDiscoveryProvider(PeopleDiscoveryKind.suggestions));
  }

  String _friendlyError(Object e) {
    if (e is ApiClientException) return e.message;
    return e.toString().replaceAll('Exception: ', '');
  }

  Future<SocialListResult> _fetchPage({String? cursor}) {
    switch (_kind) {
      case SocialListKind.friends:
        return _repo.friends(cursor: cursor);
      case SocialListKind.incoming:
        return _repo.incomingRequests(cursor: cursor);
      case SocialListKind.outgoing:
        return _repo.outgoingRequests(cursor: cursor);
      case SocialListKind.followers:
        return _repo.followers(cursor: cursor);
      case SocialListKind.following:
        return _repo.following(cursor: cursor);
      case SocialListKind.blocked:
        return _repo.blocked(cursor: cursor);
    }
  }

  Future<void> refresh() async {
    final hadItems = state.items.isNotEmpty;
    state = state.copyWith(
      initialLoading: !hadItems,
      refreshing: hadItems,
      clearError: true,
    );
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

  Future<void> _runAction(
    int userId,
    Future<void> Function() action, {
    bool removeFromListOnSuccess = false,
    void Function()? onSuccess,
  }) async {
    if (!_beginAction(userId)) return;
    try {
      await action();
      if (removeFromListOnSuccess) {
        state = state.copyWith(
          items: state.items.where((i) => i.id != userId).toList(),
        );
      }
      onSuccess?.call();
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
    } finally {
      _endAction(userId);
    }
  }

  Future<void> acceptIncoming(SocialUserSummary row) {
    final requestId = row.requestId;
    if (requestId == null) return Future.value();
    return _runAction(
      row.id,
      () => _repo.acceptRequest(requestId),
      removeFromListOnSuccess: true,
      // Accepting a request creates a new friendship — the Friends tab
      // (a separate, independently-cached controller instance kept alive
      // alongside this one inside the same TabBarView) would otherwise
      // keep showing its pre-accept snapshot until manually refreshed.
      // `ref.exists` + calling `.refresh()` (rather than `ref.invalidate`,
      // which forces a synchronous rebuild of the target element) avoids
      // waking a Friends tab the user never opened and avoids rebuilding
      // another family member from inside this one's own state update.
      onSuccess: () {
        final friendsKey = socialListProvider(SocialListKind.friends);
        if (ref.exists(friendsKey)) {
          ref.read(friendsKey.notifier).refresh();
        }
      },
    ).whenComplete(_refreshSuggestionFeed);
  }

  Future<void> declineIncoming(SocialUserSummary row) {
    final requestId = row.requestId;
    if (requestId == null) return Future.value();
    return _runAction(
      row.id,
      () => _repo.declineRequest(requestId),
      removeFromListOnSuccess: true,
    ).whenComplete(_refreshSuggestionFeed);
  }

  Future<void> cancelOutgoing(SocialUserSummary row) {
    final requestId = row.requestId;
    if (requestId == null) return Future.value();
    return _runAction(
      row.id,
      () => _repo.cancelRequest(requestId),
      removeFromListOnSuccess: true,
    ).whenComplete(_refreshSuggestionFeed);
  }

  Future<void> unfriend(SocialUserSummary row) => _runAction(
    row.id,
    () => _repo.unfriend(row.id),
    removeFromListOnSuccess: true,
  ).whenComplete(_refreshSuggestionFeed);

  Future<void> unfollow(SocialUserSummary row) => _runAction(
    row.id,
    () => _repo.unfollow(row.id),
    removeFromListOnSuccess: true,
  ).whenComplete(_refreshSuggestionFeed);

  Future<void> unblock(SocialUserSummary row) => _runAction(
    row.id,
    () => _repo.unblock(row.id),
    removeFromListOnSuccess: true,
  ).whenComplete(_refreshSuggestionFeed);
}
