import '../../domain/notification_type.dart';

class NotificationItem {
  final int id;
  final AppNotificationType type;
  final String title;
  final String body;
  final String? actorName;
  final String? actorAvatarUrl;
  final int? actorId;
  final String? deepLink;
  final DateTime createdAt;
  final DateTime? readAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.actorName,
    this.actorAvatarUrl,
    this.actorId,
    this.deepLink,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final rawActorId = json['actorId'] ?? json['actor_id'];
    final actorId = rawActorId is num ? rawActorId.toInt() : null;
    final deepLink =
        json['deepLink']?.toString() ?? json['deep_link']?.toString();
    final rawCreated =
        json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '';
    final rawRead = json['readAt']?.toString() ?? json['read_at']?.toString();

    return NotificationItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: AppNotificationType.fromCode(json['type']?.toString()),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? json['message']?.toString() ?? '',
      actorName:
          json['actorName']?.toString() ?? json['actor_name']?.toString(),
      actorAvatarUrl:
          json['actorAvatarUrl']?.toString() ??
          json['actor_avatar_url']?.toString(),
      actorId: actorId,
      deepLink: deepLink,
      createdAt: DateTime.tryParse(rawCreated) ?? DateTime.now(),
      readAt: rawRead != null ? DateTime.tryParse(rawRead) : null,
    );
  }

  String? get actionUrl {
    if (deepLink != null && deepLink!.isNotEmpty) return deepLink;
    switch (type) {
      case AppNotificationType.friendRequestReceived:
      case AppNotificationType.friendRequestAccepted:
      case AppNotificationType.userFollowed:
        return actorId != null ? '/profile/$actorId' : null;
      case AppNotificationType.adoptionLike:
      case AppNotificationType.adoptionComment:
      case AppNotificationType.adoptionApplicationSubmitted:
      case AppNotificationType.adoptionApplicationApproved:
      case AppNotificationType.adoptionApplicationRejected:
      case AppNotificationType.adoptionListingStatusChanged:
        return deepLink;
      case AppNotificationType.petFollowed:
      case AppNotificationType.petLiked:
      case AppNotificationType.campaignReminder:
      case AppNotificationType.campaignNew:
      case AppNotificationType.campaignBookingConfirmed:
      case AppNotificationType.campaignUpdate:
      case AppNotificationType.campaignCancelled:
      case AppNotificationType.vaccineReminder:
      case AppNotificationType.donationUpdate:
      case AppNotificationType.communityActivity:
      case AppNotificationType.comment:
      case AppNotificationType.like:
      case AppNotificationType.follow:
      case AppNotificationType.announcement:
      case AppNotificationType.emergency:
      case AppNotificationType.general:
        return null;
    }
  }
}

class NotificationListResponse {
  final List<NotificationItem> items;
  final int unreadCount;
  final bool hasMore;
  final int? nextCursor;

  const NotificationListResponse({
    required this.items,
    this.unreadCount = 0,
    this.hasMore = false,
    this.nextCursor,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final List<dynamic> rawList;
    if (rawData is List) {
      rawList = rawData;
    } else if (rawData is Map && rawData['items'] is List) {
      rawList = rawData['items'] as List;
    } else {
      rawList = [];
    }

    final items = rawList
        .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final dataMap = rawData is Map ? rawData : null;
    final hasMore =
        json['hasMore'] == true ||
        json['has_more'] == true ||
        dataMap?['hasMore'] == true ||
        dataMap?['has_more'] == true;

    final nextCursor =
        (json['nextCursor'] as num?)?.toInt() ??
        (json['next_cursor'] as num?)?.toInt() ??
        (dataMap?['nextCursor'] as num?)?.toInt() ??
        (dataMap?['next_cursor'] as num?)?.toInt();

    final unreadCount =
        (json['unreadCount'] as num?)?.toInt() ??
        (json['unread_count'] as num?)?.toInt() ??
        (dataMap?['unreadCount'] as num?)?.toInt() ??
        (dataMap?['unread_count'] as num?)?.toInt() ??
        0;

    return NotificationListResponse(
      items: items,
      unreadCount: unreadCount,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }
}
