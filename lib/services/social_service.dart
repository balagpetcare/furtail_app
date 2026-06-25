import 'package:furtail_app/core/network/api_endpoints.dart';
import 'api_client.dart';

class SocialStatus {
  final bool isFollowing;
  final bool isLiked;
  final bool isFriend;
  final int? outgoingRequestId;
  final int? incomingRequestId;

  SocialStatus({
    required this.isFollowing,
    required this.isLiked,
    required this.isFriend,
    required this.outgoingRequestId,
    required this.incomingRequestId,
  });

  factory SocialStatus.fromApi(Map<String, dynamic> json) {
    return SocialStatus(
      isFollowing: json['isFollowing'] == true,
      isLiked: json['isLiked'] == true,
      isFriend: json['isFriend'] == true,
      outgoingRequestId: (json['outgoingRequestId'] is num) ? (json['outgoingRequestId'] as num).toInt() : null,
      incomingRequestId: (json['incomingRequestId'] is num) ? (json['incomingRequestId'] as num).toInt() : null,
    );
  }
}

class SocialService {
  final ApiClient _client;
  SocialService({ApiClient? client}) : _client = client ?? ApiClient();

  Future<Map<String, dynamic>> getVisitorProfile(int userId) async {
    final decoded = await _client.get(ApiEndpoints.visitorProfile(userId));
    return (decoded as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> getVisitorProfileByUsername(String username) async {
    final clean = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (clean.isEmpty) throw Exception('Username is required');
    final decoded = await _client.get(ApiEndpoints.visitorProfileByUsername(clean));
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
    final decoded = await _client.post(ApiEndpoints.friendRequestSend(userId), {});
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
}
