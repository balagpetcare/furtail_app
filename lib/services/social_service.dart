import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/features/social/data/models/people_discovery_user.dart';
import 'api_client.dart';

class SocialStatus {
  final bool isFollowing;
  final bool isLiked;
  final bool isFriend;
  final int? outgoingRequestId;
  final int? incomingRequestId;
  // Not yet returned by the current /social/status endpoint — defaults to
  // false until the backend block-relationship fields land (see recovery
  // report: friend/block relationship routes were not restored on this
  // branch's social.routes.ts).
  final bool isBlocked;

  SocialStatus({
    required this.isFollowing,
    required this.isLiked,
    required this.isFriend,
    required this.outgoingRequestId,
    required this.incomingRequestId,
    this.isBlocked = false,
  });

  factory SocialStatus.fromApi(Map<String, dynamic> json) {
    return SocialStatus(
      isFollowing: json['isFollowing'] == true,
      isLiked: json['isLiked'] == true,
      isFriend: json['isFriend'] == true,
      outgoingRequestId: (json['outgoingRequestId'] is num)
          ? (json['outgoingRequestId'] as num).toInt()
          : null,
      incomingRequestId: (json['incomingRequestId'] is num)
          ? (json['incomingRequestId'] as num).toInt()
          : null,
      isBlocked: json['isBlocked'] == true,
    );
  }
}

class SocialListRow {
  final int userId;
  final int? requestId;
  final DateTime? createdAt;

  const SocialListRow({required this.userId, this.requestId, this.createdAt});

  factory SocialListRow.fromApi(Map<String, dynamic> json) {
    return SocialListRow(
      userId: (json['userId'] is num) ? (json['userId'] as num).toInt() : 0,
      requestId: (json['requestId'] is num)
          ? (json['requestId'] as num).toInt()
          : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class SocialListPage {
  final List<SocialListRow> items;
  final String? nextCursor;
  final bool hasMore;

  const SocialListPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory SocialListPage.fromApi(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return SocialListPage(
      items: rawItems
          .whereType<Map>()
          .map((e) => SocialListRow.fromApi(e.cast<String, dynamic>()))
          .toList(),
      nextCursor: json['nextCursor']?.toString(),
      hasMore: json['hasMore'] == true,
    );
  }

  static const empty = SocialListPage(
    items: [],
    nextCursor: null,
    hasMore: false,
  );
}

class SocialCounts {
  final int friends;
  final int followers;
  final int following;

  const SocialCounts({
    required this.friends,
    required this.followers,
    required this.following,
  });

  factory SocialCounts.fromApi(Map<String, dynamic> json) {
    int toInt(dynamic v) => v is num ? v.toInt() : 0;
    return SocialCounts(
      friends: toInt(json['friends']),
      followers: toInt(json['followers']),
      following: toInt(json['following']),
    );
  }

  static const zero = SocialCounts(friends: 0, followers: 0, following: 0);
}

class SocialService {
  final ApiClient _client;
  SocialService({ApiClient? client}) : _client = client ?? ApiClient();

  Future<Map<String, dynamic>> getVisitorProfile(int userId) async {
    final decoded = await _client.get(ApiEndpoints.visitorProfile(userId));
    return (decoded as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> getVisitorProfileByUsername(
    String username,
  ) async {
    final clean = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (clean.isEmpty) throw Exception('Username is required');
    final decoded = await _client.get(
      ApiEndpoints.visitorProfileByUsername(clean),
    );
    return (decoded as Map).cast<String, dynamic>();
  }

  Future<SocialStatus> getStatus(int userId) async {
    final decoded = await _client.get(ApiEndpoints.socialStatus(userId));
    final map = (decoded as Map).cast<String, dynamic>();
    final data = (map['data'] as Map?)?.cast<String, dynamic>() ?? map;
    return SocialStatus.fromApi(data);
  }

  Future<void> follow(int userId) async {
    await _client.post(ApiEndpoints.followUser(userId), {});
  }

  Future<void> unfollow(int userId) async {
    await _client.delete(ApiEndpoints.followUser(userId));
  }

  Future<void> likeProfile(int userId) async {
    await _client.post(ApiEndpoints.likeUserProfile(userId), {});
  }

  Future<void> unlikeProfile(int userId) async {
    await _client.delete(ApiEndpoints.likeUserProfile(userId));
  }

  Future<int?> sendFriendRequest(int userId) async {
    final decoded = await _client.post(
      ApiEndpoints.friendRequestSend(userId),
      {},
    );
    final map = (decoded as Map).cast<String, dynamic>();
    final data = (map['data'] as Map?)?.cast<String, dynamic>();
    if (data == null) return null;
    final id = data['requestId'];
    if (id is num) return id.toInt();
    return null;
  }

  Future<void> acceptFriendRequest(int requestId) async {
    await _client.post(ApiEndpoints.friendRequestAccept(requestId), {});
  }

  Future<void> rejectFriendRequest(int requestId) async {
    await _client.post(ApiEndpoints.friendRequestReject(requestId), {});
  }

  Future<void> cancelFriendRequest(int requestId) async {
    await _client.delete(ApiEndpoints.friendRequestCancel(requestId));
  }

  Map<String, dynamic> _data(dynamic decoded) {
    final map = (decoded as Map).cast<String, dynamic>();
    return (map['data'] as Map?)?.cast<String, dynamic>() ?? map;
  }

  // NOTE: the following endpoints (unfriend/block/unblock/list-*/discovery)
  // are not yet exposed by this branch's social.routes.ts — see the
  // messaging/friends recovery report. These client methods are wired to
  // the same REST contract the restored Flutter UI already expects so the
  // app compiles; calling them against the current backend will 404 until
  // that backend work lands.
  Future<void> unfriend(int userId) async {
    await _client.delete(ApiEndpoints.unfriend(userId));
  }

  Future<void> block(int userId) async {
    await _client.post(ApiEndpoints.blockUser(userId), {});
  }

  Future<void> unblock(int userId) async {
    await _client.delete(ApiEndpoints.unblockUser(userId));
  }

  Future<SocialCounts> getCounts(int userId) async {
    final decoded = await _client.get(ApiEndpoints.socialCounts(userId));
    return SocialCounts.fromApi(_data(decoded));
  }

  Future<SocialListPage> listFriends({int limit = 20, String? cursor}) async {
    final decoded = await _client.get(
      ApiEndpoints.socialFriends(limit: limit, cursor: cursor),
    );
    return SocialListPage.fromApi(_data(decoded));
  }

  Future<SocialListPage> listFollowers({int limit = 20, String? cursor}) async {
    final decoded = await _client.get(
      ApiEndpoints.socialFollowers(limit: limit, cursor: cursor),
    );
    return SocialListPage.fromApi(_data(decoded));
  }

  Future<SocialListPage> listFollowing({int limit = 20, String? cursor}) async {
    final decoded = await _client.get(
      ApiEndpoints.socialFollowing(limit: limit, cursor: cursor),
    );
    return SocialListPage.fromApi(_data(decoded));
  }

  Future<SocialListPage> listIncomingRequests({
    int limit = 20,
    String? cursor,
  }) async {
    final decoded = await _client.get(
      ApiEndpoints.friendRequestsIncoming(limit: limit, cursor: cursor),
    );
    return SocialListPage.fromApi(_data(decoded));
  }

  Future<SocialListPage> listOutgoingRequests({
    int limit = 20,
    String? cursor,
  }) async {
    final decoded = await _client.get(
      ApiEndpoints.friendRequestsOutgoing(limit: limit, cursor: cursor),
    );
    return SocialListPage.fromApi(_data(decoded));
  }

  Future<SocialListPage> listBlockedUsers({
    int limit = 20,
    String? cursor,
  }) async {
    final decoded = await _client.get(
      ApiEndpoints.blockedUsers(limit: limit, cursor: cursor),
    );
    return SocialListPage.fromApi(_data(decoded));
  }

  Future<PeopleDiscoveryPage> suggestedPeople({
    int limit = 20,
    String? cursor,
  }) async {
    final decoded = await _client.get(
      ApiEndpoints.peopleDiscoverySuggestions(limit: limit, cursor: cursor),
    );
    return PeopleDiscoveryPage.fromApi(_data(decoded));
  }

  Future<void> dismissPeopleSuggestion(int userId) async {
    await _client.post(ApiEndpoints.dismissPeopleSuggestion(userId), {});
  }

  Future<PeopleDiscoveryPage> searchPeople({
    required String query,
    int limit = 20,
    String? cursor,
  }) async {
    final decoded = await _client.get(
      ApiEndpoints.peopleDiscoverySearch(
        query: query,
        limit: limit,
        cursor: cursor,
      ),
    );
    return PeopleDiscoveryPage.fromApi(_data(decoded));
  }
}
