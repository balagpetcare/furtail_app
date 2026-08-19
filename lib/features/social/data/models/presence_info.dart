/// A user's Active Status, as returned by the backend's bulk presence
/// lookup (`POST /api/v1/presence/bulk`) — the single canonical shape every
/// screen (Friends, Messages inbox, Chat header) renders from. Never
/// constructed with fabricated data; when the backend has nothing to say
/// (stranger, blocked, activity status disabled, or truly never seen),
/// [isOnline] is false and [lastSeenAt] is null, and callers must render
/// no status rather than inventing one.
class PresenceInfo {
  final int userId;
  final bool isOnline;

  /// Server time, already resolved by the backend — never derived from the
  /// client's own clock.
  final DateTime? lastSeenAt;

  const PresenceInfo({
    required this.userId,
    required this.isOnline,
    required this.lastSeenAt,
  });

  static const unknown = PresenceInfo(
    userId: 0,
    isOnline: false,
    lastSeenAt: null,
  );

  factory PresenceInfo.fromApi(Map<String, dynamic> json) {
    final rawId = json['userId'];
    return PresenceInfo(
      userId: rawId is num ? rawId.toInt() : 0,
      isOnline: json['isOnline'] == true,
      lastSeenAt: DateTime.tryParse(
        json['lastSeenAt']?.toString() ?? '',
      )?.toLocal(),
    );
  }

  /// Whether there's anything at all worth rendering for this user — false
  /// for a stranger/blocked/opted-out user, in which case callers must show
  /// no presence UI at all (not even a muted "last seen" line).
  bool get hasStatus => isOnline || lastSeenAt != null;

  /// Messenger-style relative label: "Active now", "Active 5m ago",
  /// "Active yesterday", or a short date for anything older. Returns null
  /// when there is nothing to show (see [hasStatus]) — callers must not
  /// fall back to a fabricated label.
  String? get statusLabel {
    if (isOnline) return 'Active now';
    final seen = lastSeenAt;
    if (seen == null) return null;

    final now = DateTime.now();
    final diff = now.difference(seen);
    if (diff.inMinutes < 1) return 'Active just now';
    if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';

    final today = DateTime(now.year, now.month, now.day);
    final seenDay = DateTime(seen.year, seen.month, seen.day);
    final dayDiff = today.difference(seenDay).inDays;
    if (dayDiff == 1) return 'Active yesterday';
    if (dayDiff < 7) return 'Active ${dayDiff}d ago';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'Active on ${months[seen.month - 1]} ${seen.day}';
  }
}
