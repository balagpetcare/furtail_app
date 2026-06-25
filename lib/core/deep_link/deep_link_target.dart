/// Parsed deep link destination.
enum DeepLinkKind {
  campaign,
  campaignDetail,
  post,
  pet,
  fundraising,
  profile,
  friendRequests,
}

class DeepLinkTarget {
  final DeepLinkKind kind;
  final String id;

  const DeepLinkTarget({required this.kind, required this.id});

  @override
  String toString() => 'DeepLinkTarget($kind, $id)';

  @override
  bool operator ==(Object other) =>
      other is DeepLinkTarget && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}
