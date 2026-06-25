import 'package:furtail_app/features/pets/data/models/pet_model.dart';
import 'package:furtail_app/core/media/media_url.dart';

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
  final List<String> followerPreviewUrls;

  final bool canViewFullProfile;
  final bool isProfileLocked;

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
    this.followerPreviewUrls = const [],
    this.canViewFullProfile = true,
    this.isProfileLocked = false,
  });

  VisitorProfileModel copyWith({
    int? id,
    String? displayName,
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
    String? avatarUrl,
    String? coverUrl,
    int? followersCount,
    int? followingCount,
    int? petsCount,
    List<PetModel>? pets,
    List<VisitorAward>? awards,
    List<String>? galleryUrls,
    List<String>? followerPreviewUrls,
    bool? canViewFullProfile,
    bool? isProfileLocked,
  }) {
    return VisitorProfileModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
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
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      petsCount: petsCount ?? this.petsCount,
      pets: pets ?? this.pets,
      awards: awards ?? this.awards,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      followerPreviewUrls: followerPreviewUrls ?? this.followerPreviewUrls,
      canViewFullProfile: canViewFullProfile ?? this.canViewFullProfile,
      isProfileLocked: isProfileLocked ?? this.isProfileLocked,
    );
  }

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
    // API: GET /api/v1/user/:id returns
    // { success, data: { id, status, profile: { displayName, username, avatarMedia, coverMedia },
    //                    pets, galleryItems, followersCount, followingCount, followerPreviewUrls } }
    // User fields are spread directly under data — there is no data['user'] wrapper.
    final data = (root['data'] is Map)
        ? Map<String, dynamic>.from(root['data'])
        : root;

    // Profile sub-object lives at data['profile'], not data['user']['profile'].
    final profile = (data['profile'] is Map)
        ? Map<String, dynamic>.from(data['profile'])
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
          if (media is Map) {
            final raw = media['url']?.toString() ?? '';
            if (raw.trim().isEmpty) return null;
            return MediaUrl.normalize(raw);
          }
          return null;
        })
        .whereType<String>()
        .where((u) => u.trim().isNotEmpty)
        .toList();

    // Helper: try multiple keys, return first non-nullish string trimmed (or null).
    String? strVal(String key, [List<String>? altKeys]) {
      final allKeys = [key, ...?altKeys];
      for (final k in allKeys) {
        final v = profile[k];
        if (v != null) {
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
      return null;
    }

    // Display name: profile.displayName is the canonical field.
    final rawDisplayName = (profile['displayName'] ?? profile['name'] ?? '').toString().trim();
    final rawUsername = (profile['username'] ?? '').toString().trim();
    final rawBio = (profile['bio'] ?? '').toString().trim();
    final rawAvatar = (avatarMedia['url'] ?? profile['avatarUrl'] ?? '').toString().trim();
    final rawCover = (coverMedia['url'] ?? profile['coverUrl'] ?? '').toString().trim();

    // Intro/about fields (camelCase preferred, snake_case fallback)
    final parsedEducation  = strVal('education');
    final parsedPlaceLive  = strVal('placeLive', ['place_live', 'place_live']);
    final parsedFrom       = strVal('from');
    final parsedProfileType = strVal('profileType', ['profile_type']);
    final parsedWorkStatus = strVal('workStatus', ['work_status']);
    final parsedFansAndFriends = strVal('fansAndFriends', ['fans_and_friends']);
    final parsedReligiousStatus = strVal('religiousStatus', ['religious_status']);
    final parsedGender     = strVal('gender');
    final parsedMarital    = strVal('maritalStatus', ['marital_status']);
    // Birthdate — may come as ISO string or timestamp
    DateTime? parsedBirthdate;
    final bdRaw = profile['birthdate'] ?? profile['birthDate'] ?? profile['birthday'];
    if (bdRaw is String && bdRaw.trim().isNotEmpty) {
      parsedBirthdate = DateTime.tryParse(bdRaw.trim());
    } else if (bdRaw is num) {
      // Unix timestamp in seconds or milliseconds
      final ts = bdRaw.toInt();
      parsedBirthdate = DateTime.fromMillisecondsSinceEpoch(ts > 1e12 ? ts : ts * 1000);
    }

    // followersCount/followingCount are at data level, not nested under stats.
    final followersCount = (data['followersCount'] is num)
        ? (data['followersCount'] as num).toInt()
        : 0;
    final followingCount = (data['followingCount'] is num)
        ? (data['followingCount'] as num).toInt()
        : 0;

    final rawPreviews = (data['followerPreviewUrls'] as List?) ?? const [];
    final followerPreviewUrls = rawPreviews
        .whereType<String>()
        .where((u) => u.trim().isNotEmpty)
        .map(MediaUrl.normalize)
        .toList();

    final canViewFullProfile = (data['canViewFullProfile'] as bool?) ?? true;
    final isProfileLocked = (data['isProfileLocked'] as bool?) ?? false;

    return VisitorProfileModel(
      id: (data['id'] is num) ? (data['id'] as num).toInt() : 0,
      displayName: rawDisplayName.isEmpty ? 'Unknown User' : rawDisplayName,
      username: rawUsername.isEmpty ? null : rawUsername,
      bio: rawBio.isEmpty ? null : rawBio,
      education: parsedEducation,
      placeLive: parsedPlaceLive,
      from: parsedFrom,
      profileType: parsedProfileType,
      workStatus: parsedWorkStatus,
      fansAndFriends: parsedFansAndFriends,
      religiousStatus: parsedReligiousStatus,
      gender: parsedGender,
      maritalStatus: parsedMarital,
      birthdate: parsedBirthdate,
      avatarUrl: rawAvatar.isEmpty ? null : MediaUrl.normalize(rawAvatar),
      coverUrl: rawCover.isEmpty ? null : MediaUrl.normalize(rawCover),
      followersCount: followersCount,
      followingCount: followingCount,
      petsCount: pets.length,
      pets: pets,
      awards: awards,
      galleryUrls: galleryUrls,
      followerPreviewUrls: followerPreviewUrls,
      canViewFullProfile: canViewFullProfile,
      isProfileLocked: isProfileLocked,
    );
  }
}
