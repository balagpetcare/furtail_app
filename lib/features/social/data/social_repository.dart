import 'package:furtail_app/services/api_client.dart';
import 'package:furtail_app/services/social_service.dart';

import 'models/people_discovery_user.dart';
import 'models/social_user_summary.dart';

class SocialListResult {
  final List<SocialUserSummary> items;
  final String? nextCursor;
  final bool hasMore;

  const SocialListResult({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  static const empty = SocialListResult(
    items: [],
    nextCursor: null,
    hasMore: false,
  );
}

class DiscoveryListResult {
  final List<PeopleDiscoveryUser> items;
  final String? nextCursor;
  final bool hasMore;

  const DiscoveryListResult({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  static const empty = DiscoveryListResult(
    items: [],
    nextCursor: null,
    hasMore: false,
  );
}

/// Data layer for the Social hub (Friends / Incoming / Sent / Followers /
/// Following / Blocked). Wraps [SocialService] (the canonical relationship
/// API client) and hydrates each row's display name/avatar — the backend's
/// list endpoints intentionally return only `{userId, requestId?,
/// createdAt}` (see `relationships.service.ts`), so this is the one place
/// that turns those ids into something a list tile can render.
class SocialRepository {
  SocialRepository({SocialService? service})
    : _service = service ?? SocialService();

  final SocialService _service;

  Future<SocialListResult> _hydrate(SocialListPage page) async {
    final summaries = <SocialUserSummary>[];
    for (final row in page.items) {
      try {
        final raw = await _service.getVisitorProfile(row.userId);
        summaries.add(
          SocialUserSummary.fromVisitorProfileJson(
            raw,
            fallbackId: row.userId,
            requestId: row.requestId,
            since: row.createdAt,
          ),
        );
      } on ApiClientException catch (error) {
        if (error.statusCode == 404) {
          continue;
        }
        summaries.add(
          SocialUserSummary.placeholder(
            row.userId,
            requestId: row.requestId,
            since: row.createdAt,
          ),
        );
      } catch (_) {
        summaries.add(
          SocialUserSummary.placeholder(
            row.userId,
            requestId: row.requestId,
            since: row.createdAt,
          ),
        );
      }
    }
    return SocialListResult(
      items: summaries,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<SocialListResult> friends({int limit = 20, String? cursor}) async =>
      _hydrate(await _service.listFriends(limit: limit, cursor: cursor));

  Future<SocialListResult> followers({int limit = 20, String? cursor}) async =>
      _hydrate(await _service.listFollowers(limit: limit, cursor: cursor));

  Future<SocialListResult> following({int limit = 20, String? cursor}) async =>
      _hydrate(await _service.listFollowing(limit: limit, cursor: cursor));

  Future<SocialListResult> incomingRequests({
    int limit = 20,
    String? cursor,
  }) async => _hydrate(
    await _service.listIncomingRequests(limit: limit, cursor: cursor),
  );

  Future<SocialListResult> outgoingRequests({
    int limit = 20,
    String? cursor,
  }) async => _hydrate(
    await _service.listOutgoingRequests(limit: limit, cursor: cursor),
  );

  Future<SocialListResult> blocked({int limit = 20, String? cursor}) async =>
      _hydrate(await _service.listBlockedUsers(limit: limit, cursor: cursor));

  Future<DiscoveryListResult> suggestions({
    int limit = 20,
    String? cursor,
  }) async {
    final page = await _service.suggestedPeople(limit: limit, cursor: cursor);
    return DiscoveryListResult(
      items: page.items.where((item) => item.id > 0).toList(growable: false),
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<DiscoveryListResult> search({
    required String query,
    int limit = 20,
    String? cursor,
  }) async {
    final page = await _service.searchPeople(
      query: query,
      limit: limit,
      cursor: cursor,
    );
    return DiscoveryListResult(
      items: page.items.where((item) => item.id > 0).toList(growable: false),
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<SocialCounts> counts(int userId) => _service.getCounts(userId);

  Future<void> acceptRequest(int requestId) =>
      _service.acceptFriendRequest(requestId);
  Future<void> declineRequest(int requestId) =>
      _service.rejectFriendRequest(requestId);
  Future<void> cancelRequest(int requestId) =>
      _service.cancelFriendRequest(requestId);
  Future<void> unfriend(int userId) => _service.unfriend(userId);
  Future<void> follow(int userId) => _service.follow(userId);
  Future<void> unfollow(int userId) => _service.unfollow(userId);
  Future<int?> sendFriendRequest(int userId) =>
      _service.sendFriendRequest(userId);
  Future<void> block(int userId) => _service.block(userId);
  Future<void> unblock(int userId) => _service.unblock(userId);
  Future<void> dismissSuggestion(int userId) =>
      _service.dismissPeopleSuggestion(userId);
}
