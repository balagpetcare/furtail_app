/// Parsed deep link destination.
enum DeepLinkKind {
  campaign,
  campaignDetail,
  post,
  pet,
  fundraising,
  profile,
  friendRequests,
  adoption,
  adoptionComments,
  adoptionApplication,

  /// Password-reset deep link from the Central Auth reset email
  /// (`furtail://reset-password?token=...` or
  /// `https://app.furtail.global/reset-password?token=...`). Here [id] carries
  /// the opaque reset token (from the `token` query param), not a resource id.
  resetPassword,
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
