import 'package:furtail_app/features/pets/data/models/pet_model.dart';
import 'package:furtail_app/core/media/media_url.dart';

class UserProfileModel {
  final int id;
  final String name;
  final List<String> galleryUrls;

  final String? email;
  final String? phone;
  final String? username;
  final String? bio;

  // About details
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

  const UserProfileModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.username,
    this.bio,
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

    // ✅ Media objects (backend returns nested avatarMedia/coverMedia)
    final avatarMedia = (profile["avatarMedia"] is Map)
        ? (profile["avatarMedia"] as Map)
        : null;
    final coverMedia = (profile["coverMedia"] is Map)
        ? (profile["coverMedia"] as Map)
        : null;

    final displayName =
        (profile["displayName"] ?? profile["name"] ?? data["name"] ?? "")
            .toString()
            .trim();

    final petsRaw = (data["pets"] as List?) ?? const [];

    // ✅ PetModel unchanged, just use it:
    final pets = petsRaw
        .whereType<Map>()
        .map((e) => PetModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final points = _toInt(wallet["points"]);
    final computedRank = _rankFromPoints(points);

    final galleryRaw = (data["galleryItems"] as List?) ?? const [];

    final galleryUrls = galleryRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map((item) {
          final media = item["media"];
          if (media is Map) {
            return media["url"]?.toString();
          }
          return null;
        })
        .whereType<String>()
        .where((u) => u.trim().isNotEmpty)
        .toList();

    final followerPreview = (data["followerPreviewUrls"] as List?)
            ?.map((e) => e?.toString())
            .whereType<String>()
            .where((u) => u.trim().isNotEmpty)
            .toList() ??
        const <String>[];

    return UserProfileModel(
      id: _toInt(data["id"]),
      name: displayName.isEmpty ? "Furtail Member" : displayName,
      email: auth["email"]?.toString() ?? data["email"]?.toString(),
      phone: auth["phone"]?.toString() ?? data["phone"]?.toString(),
      username: profile["username"]?.toString(),
      bio: profile["bio"]?.toString() ?? data["bio"]?.toString(),
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
      followerPreviewUrls: followerPreview,
      rank: computedRank,
      // ✅ Prefer nested media url (new backend shape), fallback to older keys if present.
      photoUrl: MediaUrl.normalize((avatarMedia?["url"]?.toString() ?? profile["photoUrl"]?.toString() ?? data["photoUrl"]?.toString() ?? '').toString()),
      coverUrl: MediaUrl.normalize((coverMedia?["url"]?.toString() ?? profile["coverUrl"]?.toString() ?? '').toString()),
      pets: pets,
      galleryUrls: galleryUrls,
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
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      username: username ?? this.username,
      bio: bio ?? this.bio,
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
