/// Simple relative time formatting for fundraising UI.
String fundraisingTimeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);

  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  final weeks = (diff.inDays / 7).floor();
  if (weeks < 4) return '${weeks}w ago';

  final months = (diff.inDays / 30).floor();
  if (months < 12) return '${months}mo ago';

  final years = (diff.inDays / 365).floor();
  return '${years}y ago';
}
