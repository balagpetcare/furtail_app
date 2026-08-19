import 'package:furtail_app/core/media/media_url.dart';

/// Minimal user display info for a Social hub list row (Friends,
/// Followers, Following, Incoming/Sent requests, Blocked). Deliberately
/// lighter than `VisitorProfileModel` — list rows only need a name/avatar,
/// not pets/awards/gallery — parsed from the same
/// `GET /api/v1/user/:id` response shape.
class SocialUserSummary {
  final int id;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  String? resolvedAvatarUrl() =>
      avatarUrl != null ? MediaUrl.normalize(avatarUrl!) : null;

  /// Present for incoming/outgoing friend-request rows only.
  final int? requestId;

  /// When this relationship/request was created (server `createdAt`).
  final DateTime? since;

  const SocialUserSummary({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.requestId,
    this.since,
  });

  factory SocialUserSummary.fromVisitorProfileJson(
    Map<String, dynamic> root, {
    required int fallbackId,
    int? requestId,
    DateTime? since,
  }) {
    final data = (root['data'] is Map)
        ? Map<String, dynamic>.from(root['data'])
        : root;
    final profile = (data['profile'] is Map)
        ? Map<String, dynamic>.from(data['profile'])
        : const <String, dynamic>{};
    final avatarMedia = (profile['avatarMedia'] is Map)
        ? Map<String, dynamic>.from(profile['avatarMedia'])
        : const <String, dynamic>{};

    final rawId = data['id'];
    final id = rawId is num ? rawId.toInt() : fallbackId;
    final displayName = (profile['displayName'] ?? profile['name'] ?? '')
        .toString()
        .trim();
    final username = (profile['username'] ?? '').toString().trim();
    final avatarUrl = (avatarMedia['url'] ?? profile['avatarUrl'] ?? '')
        .toString()
        .trim();

    return SocialUserSummary(
      id: id,
      displayName: displayName.isEmpty ? 'Furtail Member' : displayName,
      username: username.isEmpty ? null : username,
      avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
      requestId: requestId,
      since: since,
    );
  }

  /// Used when the profile lookup for a list row fails (e.g. transient
  /// network error) — keeps the row visible instead of dropping it.
  factory SocialUserSummary.placeholder(
    int id, {
    int? requestId,
    DateTime? since,
  }) => SocialUserSummary(
    id: id,
    displayName: 'Furtail Member',
    requestId: requestId,
    since: since,
  );
}
