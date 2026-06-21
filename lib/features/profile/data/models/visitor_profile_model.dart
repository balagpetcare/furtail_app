import 'package:bpa_app/features/pets/data/models/pet_model.dart';
import 'package:bpa_app/core/media/media_url.dart';

class VisitorAward {
  final String title;
  final String? iconUrl;
  const VisitorAward({required this.title, this.iconUrl});
}

class VisitorProfileModel {
  final int id;
  final String displayName;
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
  final String? avatarUrl;
  final String? coverUrl;

  final int followersCount;
  final int followingCount;
  final int petsCount;

  final List<PetModel> pets;
  final List<VisitorAward> awards;
  final List<String> galleryUrls;

  const VisitorProfileModel({
    required this.id,
    required this.displayName,
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
    this.avatarUrl,
    this.coverUrl,
    required this.followersCount,
    required this.followingCount,
    required this.petsCount,
    required this.pets,
    required this.awards,
    required this.galleryUrls,
  });

  /// ---------------------------------------------------------------------------
  /// Compatibility getters (UI expects these fields)
  /// এগুলো থাকলে visitor_profile_screen.dart এ city/following/liked এরর আর হবে না।
  /// বর্তমানে API response থেকে এগুলোর ডাটা আসছে না, তাই null রাখা হয়েছে।
  /// পরে API তে যোগ হলে এখানে parse করে সেট করা যাবে।
  /// ---------------------------------------------------------------------------
  String? get city => null;

  bool? get following => null;

  bool? get liked => null;

  factory VisitorProfileModel.fromApi(Map<String, dynamic> root) {
    // API: { success, data: { user: { id, profile, stats }, pets, achievements, galleryItems } }
    final data = (root['data'] is Map)
        ? Map<String, dynamic>.from(root['data'])
        : root;
    final user = (data['user'] is Map)
        ? Map<String, dynamic>.from(data['user'])
        : const <String, dynamic>{};
    final profile = (user['profile'] is Map)
        ? Map<String, dynamic>.from(user['profile'])
        : const <String, dynamic>{};
    final stats = (user['stats'] is Map)
        ? Map<String, dynamic>.from(user['stats'])
        : const <String, dynamic>{};

    final avatarMedia = (profile['avatarMedia'] is Map)
        ? Map<String, dynamic>.from(profile['avatarMedia'])
        : const <String, dynamic>{};
    final coverMedia = (profile['coverMedia'] is Map)
        ? Map<String, dynamic>.from(profile['coverMedia'])
        : const <String, dynamic>{};

    final petsRaw = (data['pets'] as List?) ?? const [];
    final pets = petsRaw
        .whereType<Map>()
        .map((e) => PetModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final achievementsRaw = (data['achievements'] as List?) ?? const [];
    final awards = achievementsRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map((ua) {
          final ach = (ua['achievement'] is Map)
              ? Map<String, dynamic>.from(ua['achievement'])
              : const <String, dynamic>{};
          final icon = (ach['iconMedia'] is Map)
              ? Map<String, dynamic>.from(ach['iconMedia'])
              : const <String, dynamic>{};
          return VisitorAward(
            title: (ach['title'] ?? ach['code'] ?? 'Award').toString(),
            iconUrl: icon['url']?.toString(),
          );
        })
        .toList();

    final galleryRaw = (data['galleryItems'] as List?) ?? const [];
    final galleryUrls = galleryRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map((item) {
          final media = item['media'];
          if (media is Map) return media['url']?.toString();
          return null;
        })
        .whereType<String>()
        .where((u) => u.trim().isNotEmpty)
        .toList();

    return VisitorProfileModel(
      id: (user['id'] is num) ? (user['id'] as num).toInt() : 0,
      displayName: (profile['displayName'] ?? 'BPA Member').toString(),
      username: profile['username']?.toString(),
      bio: profile['bio']?.toString(),
      avatarUrl: MediaUrl.normalize((avatarMedia['url']?.toString() ?? '').toString()),
      coverUrl: MediaUrl.normalize((coverMedia['url']?.toString() ?? '').toString()),
      followersCount: (stats['followersCount'] is num)
          ? (stats['followersCount'] as num).toInt()
          : 0,
      followingCount: (stats['followingCount'] is num)
          ? (stats['followingCount'] as num).toInt()
          : 0,
      petsCount: (stats['petsCount'] is num)
          ? (stats['petsCount'] as num).toInt()
          : pets.length,
      pets: pets,
      awards: awards,
      galleryUrls: galleryUrls,
    );
  }
}
