import '../../domain/notification_type.dart';

class NotificationPayload {
  final AppNotificationType type;
  final String title;
  final String body;
  final String? actionUrl;
  final String? notificationId;
  final String? actorName;
  final String? actorAvatarUrl;
  final Map<String, String> data;

  const NotificationPayload({
    required this.type,
    required this.title,
    required this.body,
    this.actionUrl,
    this.notificationId,
    this.actorName,
    this.actorAvatarUrl,
    this.data = const {},
  });

  factory NotificationPayload.fromFcmMap(Map<String, dynamic> message) {
    final data = message.map(
      (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
    );
    final notification = message['notification'];
    Map<String, dynamic> nested = const {};
    if (notification is Map) {
      nested = Map<String, dynamic>.from(notification);
    }

    final title = data['title'] ??
        nested['title']?.toString() ??
        'Furtail';
    final body = data['body'] ??
        data['message'] ??
        nested['body']?.toString() ??
        '';

    // Backend social notifications send 'route'/'deepLink' instead of 'actionUrl'.
    final actionUrl = data['actionUrl'] ?? data['action_url'] ??
        data['route'] ?? data['deepLink'];

    return NotificationPayload(
      type: AppNotificationType.fromCode(data['type']),
      title: title,
      body: body,
      actionUrl: actionUrl,
      notificationId: data['notificationId'] ?? data['notification_id'],
      actorName: data['actorName'] ?? data['actor_name'],
      actorAvatarUrl: data['actorAvatarUrl'] ?? data['actor_avatar_url'],
      data: data,
    );
  }

  factory NotificationPayload.local({
    required AppNotificationType type,
    required String title,
    required String body,
    String? actionUrl,
    String? dedupeKey,
  }) {
    return NotificationPayload(
      type: type,
      title: title,
      body: body,
      actionUrl: actionUrl,
      notificationId: dedupeKey,
      data: {
        if (dedupeKey != null) 'dedupeKey': dedupeKey,
      },
    );
  }
}
