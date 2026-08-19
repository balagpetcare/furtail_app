import 'package:furtail_app/core/media/media_url.dart';

class PeopleDiscoveryUser {
  final int id;
  final String publicId;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final String? placeLive;
  final String? from;
  final int mutualFriendsCount;
  final int mutualFollowsCount;
  final int publicActivityCount;
  final DateTime? latestActivityAt;
  final bool isFriend;
  final String friendRequestState;
  final int? friendRequestId;
  final bool isFollowing;
  final bool followsMe;
  final bool interactionAllowed;
  final bool canViewFullProfile;

  String? resolvedAvatarUrl() =>
      avatarUrl != null ? MediaUrl.normalize(avatarUrl!) : null;

  const PeopleDiscoveryUser({
    required this.id,
    required this.publicId,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.bio,
    required this.placeLive,
    required this.from,
    required this.mutualFriendsCount,
    required this.mutualFollowsCount,
    required this.publicActivityCount,
    required this.latestActivityAt,
    required this.isFriend,
    required this.friendRequestState,
    required this.friendRequestId,
    required this.isFollowing,
    required this.followsMe,
    required this.interactionAllowed,
    required this.canViewFullProfile,
  });

  PeopleDiscoveryUser copyWith({
    int? id,
    String? publicId,
    String? displayName,
    String? username,
    String? avatarUrl,
    String? bio,
    String? placeLive,
    String? from,
    int? mutualFriendsCount,
    int? mutualFollowsCount,
    int? publicActivityCount,
    DateTime? latestActivityAt,
    bool? isFriend,
    String? friendRequestState,
    int? friendRequestId,
    bool? isFollowing,
    bool? followsMe,
    bool? interactionAllowed,
    bool? canViewFullProfile,
  }) {
    return PeopleDiscoveryUser(
      id: id ?? this.id,
      publicId: publicId ?? this.publicId,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      placeLive: placeLive ?? this.placeLive,
      from: from ?? this.from,
      mutualFriendsCount: mutualFriendsCount ?? this.mutualFriendsCount,
      mutualFollowsCount: mutualFollowsCount ?? this.mutualFollowsCount,
      publicActivityCount: publicActivityCount ?? this.publicActivityCount,
      latestActivityAt: latestActivityAt ?? this.latestActivityAt,
      isFriend: isFriend ?? this.isFriend,
      friendRequestState: friendRequestState ?? this.friendRequestState,
      friendRequestId: friendRequestId ?? this.friendRequestId,
      isFollowing: isFollowing ?? this.isFollowing,
      followsMe: followsMe ?? this.followsMe,
      interactionAllowed: interactionAllowed ?? this.interactionAllowed,
      canViewFullProfile: canViewFullProfile ?? this.canViewFullProfile,
    );
  }

  bool get hasIncomingRequest => friendRequestState == 'INCOMING_PENDING';
  bool get hasOutgoingRequest => friendRequestState == 'OUTGOING_PENDING';
  bool get canFollow => interactionAllowed && !isFollowing;
  bool get canUnfollow => interactionAllowed && isFollowing;
  bool get canSendFriendRequest =>
      interactionAllowed &&
      !isFriend &&
      !hasIncomingRequest &&
      !hasOutgoingRequest;

  String? get locationLabel {
    final live = (placeLive ?? '').trim();
    if (live.isNotEmpty) return live;
    final origin = (from ?? '').trim();
    if (origin.isNotEmpty) return origin;
    return null;
  }

  String? get mutualContextLabel {
    final parts = <String>[];
    if (mutualFriendsCount > 0) {
      parts.add(
        '$mutualFriendsCount mutual friend${mutualFriendsCount == 1 ? '' : 's'}',
      );
    }
    if (mutualFollowsCount > 0) {
      parts.add(
        '$mutualFollowsCount shared follow${mutualFollowsCount == 1 ? '' : 's'}',
      );
    }
    if (locationLabel != null) {
      parts.add(locationLabel!);
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  String? get primaryContextLabel {
    if (mutualFriendsCount > 0) {
      return '$mutualFriendsCount mutual friend${mutualFriendsCount == 1 ? '' : 's'}';
    }
    if (mutualFollowsCount > 0) {
      return '$mutualFollowsCount shared follow${mutualFollowsCount == 1 ? '' : 's'}';
    }
    return locationLabel;
  }

  factory PeopleDiscoveryUser.fromApi(Map<String, dynamic> root) {
    final data = (root['data'] is Map)
        ? Map<String, dynamic>.from(root['data'])
        : root;
    String? text(dynamic value) {
      final s = value?.toString().trim();
      return (s != null && s.isNotEmpty) ? s : null;
    }

    return PeopleDiscoveryUser(
      id: (data['id'] is num) ? (data['id'] as num).toInt() : 0,
      publicId: text(data['publicId']) ?? '',
      displayName: text(data['displayName']) ?? 'Furtail Member',
      username: text(data['username']),
      avatarUrl: text(data['avatarUrl']),
      bio: text(data['bio']),
      placeLive: text(data['placeLive']),
      from: text(data['from']),
      mutualFriendsCount: (data['mutualFriendsCount'] is num)
          ? (data['mutualFriendsCount'] as num).toInt()
          : 0,
      mutualFollowsCount: (data['mutualFollowsCount'] is num)
          ? (data['mutualFollowsCount'] as num).toInt()
          : 0,
      publicActivityCount: (data['publicActivityCount'] is num)
          ? (data['publicActivityCount'] as num).toInt()
          : 0,
      latestActivityAt: DateTime.tryParse(
        data['latestActivityAt']?.toString() ?? '',
      ),
      isFriend: data['isFriend'] == true,
      friendRequestState: data['friendRequestState']?.toString() ?? 'NONE',
      friendRequestId: (data['friendRequestId'] is num)
          ? (data['friendRequestId'] as num).toInt()
          : null,
      isFollowing: data['isFollowing'] == true,
      followsMe: data['followsMe'] == true,
      interactionAllowed: data['interactionAllowed'] != false,
      canViewFullProfile: data['canViewFullProfile'] == true,
    );
  }
}

class PeopleDiscoveryPage {
  final List<PeopleDiscoveryUser> items;
  final String? nextCursor;
  final bool hasMore;

  const PeopleDiscoveryPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory PeopleDiscoveryPage.fromApi(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return PeopleDiscoveryPage(
      items: rawItems
          .whereType<Map>()
          .map((e) => PeopleDiscoveryUser.fromApi(e.cast<String, dynamic>()))
          .toList(),
      nextCursor: json['nextCursor']?.toString(),
      hasMore: json['hasMore'] == true,
    );
  }

  static const empty = PeopleDiscoveryPage(
    items: [],
    nextCursor: null,
    hasMore: false,
  );
}
