import 'package:furtail_app/core/media/media_url.dart';
import 'package:furtail_app/features/pets/data/models/pet_model.dart';
import 'package:furtail_app/features/pets/data/pet_api_envelope.dart';

class UserProfileModel {
  final int id;
  final String name;
  final List<String> galleryUrls;
  final String? email;
  final String? phone;
  final String? username;
  final String? bio;
  final String visibility;
  final bool showEmail;
  final bool showPhone;
  final String? education;
  final String? placeLive;
  final String? fansAndFriends;
  final String? from;
  final String? profileType;
  final String? workStatus;
  final String? religiousStatus;
  final String? gender;
  final DateTime? birthdate;
  final String? maritalStatus;
  final int points;
  final double balance;
  final String? tier;
  final int followers;
  final int following;
  final List<String> followerPreviewUrls;
  final int? rank;
  final String? photoUrl;
  final String? coverUrl;
  final List<PetModel> pets;
  final String? defaultPostAudience;
  final String? followersVisibility;
  final bool? discoverableByEmail;
  final bool? discoverableByPhone;
  final bool? discoverableBySearch;
  final String? whoCanFollow;
  final String? whoCanMessage;
  final String? whoCanComment;
  final String? whoCanMention;
  final String? whoCanTag;
  final bool? requiresTagReview;
  final bool? requiresProfilePostReview;
  final bool? showActivityStatus;
  final bool? showReadReceipts;
  final Map<String, dynamic>? notificationPreferences;

  const UserProfileModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.username,
    this.bio,
    this.visibility = 'PUBLIC',
    this.showEmail = false,
    this.showPhone = false,
    this.education,
    this.placeLive,
    this.fansAndFriends,
    this.from,
    this.profileType,
    this.workStatus,
    this.religiousStatus,
    this.gender,
    this.birthdate,
    this.maritalStatus,
    required this.points,
    required this.balance,
    this.tier,
    required this.followers,
    required this.following,
    required this.followerPreviewUrls,
    this.rank,
    this.photoUrl,
    this.coverUrl,
    required this.pets,
    required this.galleryUrls,
    this.defaultPostAudience,
    this.followersVisibility,
    this.discoverableByEmail,
    this.discoverableByPhone,
    this.discoverableBySearch,
    this.whoCanFollow,
    this.whoCanMessage,
    this.whoCanComment,
    this.whoCanMention,
    this.whoCanTag,
    this.requiresTagReview,
    this.requiresProfilePostReview,
    this.showActivityStatus,
    this.showReadReceipts,
    this.notificationPreferences,
  });

  factory UserProfileModel.fromApi(Map<String, dynamic> root) {
    final data = (root["data"] is Map)
        ? (root["data"] as Map<String, dynamic>)
        : root;

    final auth = (data["auth"] is Map)
        ? (data["auth"] as Map<String, dynamic>)
        : const <String, dynamic>{};
    final profile = (data["profile"] is Map)
        ? (data["profile"] as Map<String, dynamic>)
        : const <String, dynamic>{};
    final wallet = (data["wallet"] is Map)
        ? (data["wallet"] as Map<String, dynamic>)
        : const <String, dynamic>{};

    final avatarMedia = profile["avatarMedia"] is Map
        ? profile["avatarMedia"] as Map
        : null;
    final coverMedia = profile["coverMedia"] is Map
        ? profile["coverMedia"] as Map
        : null;

    final displayName =
        (profile["displayName"] ?? profile["name"] ?? data["name"] ?? "")
            .toString()
            .trim();

    final pets = PetApiEnvelope.optionalList(
      data["pets"],
    ).map(PetModel.fromJson).toList(growable: false);

    final galleryUrls = PetApiEnvelope.optionalList(data["galleryItems"])
        .map((item) {
          final media = item["media"];
          if (media is Map) return media["url"]?.toString();
          return null;
        })
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false);

    final points = _toInt(wallet["points"]);

    return UserProfileModel(
      id: _toInt(data["id"]),
      name: displayName.isEmpty ? "Furtail Member" : displayName,
      email: auth["email"]?.toString() ?? data["email"]?.toString(),
      phone: auth["phone"]?.toString() ?? data["phone"]?.toString(),
      username: profile["username"]?.toString(),
      bio: profile["bio"]?.toString() ?? data["bio"]?.toString(),
      visibility: profile["visibility"]?.toString() ?? 'PUBLIC',
      showEmail: profile["showEmail"] == true,
      showPhone: profile["showPhone"] == true,
      education: profile["education"]?.toString(),
      placeLive: profile["placeLive"]?.toString(),
      fansAndFriends: profile["fansAndFriends"]?.toString(),
      from: profile["from"]?.toString(),
      profileType: profile["profileType"]?.toString(),
      workStatus: profile["workStatus"]?.toString(),
      religiousStatus: profile["religiousStatus"]?.toString(),
      gender: profile["gender"]?.toString(),
      birthdate: DateTime.tryParse((profile["birthdate"] ?? "").toString()),
      maritalStatus: profile["maritalStatus"]?.toString(),
      points: points,
      balance: _toDouble(wallet["balance"]),
      tier: wallet["tier"]?.toString(),
      followers: _toInt(data["followersCount"] ?? data["followers"] ?? 0),
      following: _toInt(data["followingCount"] ?? 0),
      followerPreviewUrls: _stringList(data["followerPreviewUrls"]),
      rank: _rankFromPoints(points),
      photoUrl: _normalizedUrl(
        avatarMedia?["url"]?.toString() ??
            profile["photoUrl"]?.toString() ??
            data["photoUrl"]?.toString(),
      ),
      coverUrl: _normalizedUrl(
        coverMedia?["url"]?.toString() ?? profile["coverUrl"]?.toString(),
      ),
      pets: pets,
      galleryUrls: galleryUrls,
      defaultPostAudience: profile["defaultPostAudience"]?.toString(),
      followersVisibility: profile["followersVisibility"]?.toString(),
      discoverableByEmail: profile["discoverableByEmail"] as bool?,
      discoverableByPhone: profile["discoverableByPhone"] as bool?,
      discoverableBySearch: profile["discoverableBySearch"] as bool?,
      whoCanFollow: profile["whoCanFollow"]?.toString(),
      whoCanMessage: profile["whoCanMessage"]?.toString(),
      whoCanComment: profile["whoCanComment"]?.toString(),
      whoCanMention: profile["whoCanMention"]?.toString(),
      whoCanTag: profile["whoCanTag"]?.toString(),
      requiresTagReview: profile["requiresTagReview"] as bool?,
      requiresProfilePostReview: profile["requiresProfilePostReview"] as bool?,
      showActivityStatus: profile["showActivityStatus"] as bool?,
      showReadReceipts: profile["showReadReceipts"] as bool?,
      notificationPreferences: profile["notificationPreferences"] is Map
          ? Map<String, dynamic>.from(profile["notificationPreferences"] as Map)
          : null,
    );
  }

  UserProfileModel copyWith({
    int? id,
    String? name,
    List<String>? galleryUrls,
    String? email,
    String? phone,
    String? username,
    String? bio,
    String? visibility,
    bool? showEmail,
    bool? showPhone,
    String? education,
    String? placeLive,
    String? fansAndFriends,
    String? from,
    String? profileType,
    String? workStatus,
    String? religiousStatus,
    String? gender,
    DateTime? birthdate,
    String? maritalStatus,
    int? points,
    double? balance,
    String? tier,
    int? followers,
    int? following,
    List<String>? followerPreviewUrls,
    int? rank,
    String? photoUrl,
    String? coverUrl,
    List<PetModel>? pets,
    String? defaultPostAudience,
    String? followersVisibility,
    bool? discoverableByEmail,
    bool? discoverableByPhone,
    bool? discoverableBySearch,
    String? whoCanFollow,
    String? whoCanMessage,
    String? whoCanComment,
    String? whoCanMention,
    String? whoCanTag,
    bool? requiresTagReview,
    bool? requiresProfilePostReview,
    bool? showActivityStatus,
    bool? showReadReceipts,
    Map<String, dynamic>? notificationPreferences,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      visibility: visibility ?? this.visibility,
      showEmail: showEmail ?? this.showEmail,
      showPhone: showPhone ?? this.showPhone,
      education: education ?? this.education,
      placeLive: placeLive ?? this.placeLive,
      fansAndFriends: fansAndFriends ?? this.fansAndFriends,
      from: from ?? this.from,
      profileType: profileType ?? this.profileType,
      workStatus: workStatus ?? this.workStatus,
      religiousStatus: religiousStatus ?? this.religiousStatus,
      gender: gender ?? this.gender,
      birthdate: birthdate ?? this.birthdate,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      points: points ?? this.points,
      balance: balance ?? this.balance,
      tier: tier ?? this.tier,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      followerPreviewUrls: followerPreviewUrls ?? this.followerPreviewUrls,
      rank: rank ?? this.rank,
      photoUrl: photoUrl ?? this.photoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      pets: pets ?? this.pets,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      defaultPostAudience: defaultPostAudience ?? this.defaultPostAudience,
      followersVisibility: followersVisibility ?? this.followersVisibility,
      discoverableByEmail: discoverableByEmail ?? this.discoverableByEmail,
      discoverableByPhone: discoverableByPhone ?? this.discoverableByPhone,
      discoverableBySearch: discoverableBySearch ?? this.discoverableBySearch,
      whoCanFollow: whoCanFollow ?? this.whoCanFollow,
      whoCanMessage: whoCanMessage ?? this.whoCanMessage,
      whoCanComment: whoCanComment ?? this.whoCanComment,
      whoCanMention: whoCanMention ?? this.whoCanMention,
      whoCanTag: whoCanTag ?? this.whoCanTag,
      requiresTagReview: requiresTagReview ?? this.requiresTagReview,
      requiresProfilePostReview:
          requiresProfilePostReview ?? this.requiresProfilePostReview,
      showActivityStatus: showActivityStatus ?? this.showActivityStatus,
      showReadReceipts: showReadReceipts ?? this.showReadReceipts,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v?.toString() ?? "") ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? "") ?? 0.0;
  }

  static int? _rankFromPoints(int points) {
    if (points <= 0) return null;
    if (points >= 5000) return 5;
    if (points >= 2000) return 25;
    if (points >= 1000) return 80;
    return 200;
  }
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const <String>[];
  return raw
      .map((value) => value?.toString().trim() ?? '')
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

String? _normalizedUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final normalized = MediaUrl.normalize(value).trim();
  return normalized.isEmpty ? null : normalized;
}
