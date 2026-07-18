import 'package:furtail_app/core/media/media_url.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';

/// Small embedded fundraising campaign summary for rendering fundraising posts
/// inside the general home feed.
///
/// The posts feed may include this object under `fundraisingCampaign`.
/// Keep all fields optional so older backend payloads (id only) still work.
class FundraisingEmbedModel {
  final int id;
  final String? title;
  final int? targetAmount;
  final int? raisedAmount;
  final DateTime? deadline;
  final bool? isAccountVerified;
  final String? category;
  final String? locationText;
  final List<FundraisingDonor> last3Donors;

  const FundraisingEmbedModel({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.raisedAmount,
    required this.deadline,
    required this.isAccountVerified,
    required this.category,
    required this.locationText,
    required this.last3Donors,
  });

  factory FundraisingEmbedModel.fromJson(Map<String, dynamic> json) {
    DateTime? deadline;
    final dl = json['deadline']?.toString();
    if (dl != null && dl.isNotEmpty) deadline = DateTime.tryParse(dl);

    final stats = (json['stats'] is Map)
        ? Map<String, dynamic>.from(json['stats'] as Map)
        : const <String, dynamic>{};

    final account = (json['account'] is Map)
        ? Map<String, dynamic>.from(json['account'] as Map)
        : const <String, dynamic>{};

    final last3 = (json['last3Donors'] as List?) ?? const [];
    final donors = last3
        .whereType<Map>()
        .map((e) => FundraisingDonor.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return FundraisingEmbedModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString(),
      targetAmount: (json['targetAmount'] as num?)?.toInt(),
      raisedAmount:
          (stats['raisedAmount'] as num?)?.toInt() ??
          (json['raisedAmount'] as num?)?.toInt(),
      deadline: deadline,
      isAccountVerified:
          (account['status']?.toString().toUpperCase() == 'VERIFIED')
          ? true
          : (json['isAccountVerified'] as bool?),
      category: json['category']?.toString(),
      locationText: json['locationText']?.toString(),
      last3Donors: donors,
    );
  }

  int get safeTarget => targetAmount ?? 0;
  int get safeRaised => raisedAmount ?? 0;

  int get remainingAmount {
    final t = safeTarget;
    if (t <= 0) return 0;
    final r = t - safeRaised;
    return r < 0 ? 0 : r;
  }

  double get progress {
    final t = safeTarget;
    if (t <= 0) return 0;
    final p = safeRaised / t;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  int? get remainingDays {
    if (deadline == null) return null;
    final now = DateTime.now();
    final d = deadline!;
    final diff = d.difference(DateTime(now.year, now.month, now.day));
    return diff.inDays;
  }
}

class PostMediaModel {
  final int id;
  final String url;
  final String? hlsUrl;
  final String type; // IMAGE / VIDEO
  final String status; // PENDING / PROCESSING / READY / FAILED
  final String? processingError;
  final String? thumbnailUrl;
  final int? width;
  final int? height;

  PostMediaModel({
    required this.id,
    required this.url,
    this.hlsUrl,
    required this.type,
    this.status = 'READY',
    this.processingError,
    this.thumbnailUrl,
    this.width,
    this.height,
  });

  bool get isPending => status == 'PENDING' || status == 'PROCESSING';
  bool get isFailed => status == 'FAILED';
  bool get isReady => status == 'READY' || status == 'COMPLETED';
  bool get hasPlayableStream => playbackUrl.isNotEmpty;
  bool get showProcessingBadge => isPending && !hasPlayableStream;
  String get playbackUrl =>
      (hlsUrl != null && hlsUrl!.isNotEmpty) ? hlsUrl! : url;

  factory PostMediaModel.fromJson(Map<String, dynamic> json) {
    bool looksLikeVideo(String url) {
      final u = url.toLowerCase();
      return RegExp(r'\.(mp4|mov|m4v|webm|mkv|avi)(\?|$)').hasMatch(u);
    }

    bool looksLikeImage(String url) {
      final u = url.toLowerCase();
      return RegExp(r'\.(png|jpe?g|gif|webp)(\?|$)').hasMatch(u);
    }

    String normalizeUrl(String raw) => MediaUrl.normalize(raw);

    final rawType = (json['type'] ?? '').toString().trim();
    final mime = (json['mimeType'] ?? json['mimetype'] ?? '')
        .toString()
        .toLowerCase();
    final rawStatus = (json['status'] ?? 'READY').toString().toUpperCase();
    final hlsRaw = (json['hlsUrl'] ?? json['hls_url'])?.toString();
    final thumbRaw = json['thumbnailUrl']?.toString();

    return PostMediaModel(
      id: (json['id'] as num).toInt(),
      url: normalizeUrl((json['url'] ?? '').toString()),
      hlsUrl: hlsRaw != null && hlsRaw.isNotEmpty ? normalizeUrl(hlsRaw) : null,
      status: rawStatus,
      processingError: (json['processingError'] ?? json['processing_error'])
          ?.toString(),
      thumbnailUrl: thumbRaw != null && thumbRaw.isNotEmpty
          ? MediaUrl.normalize(thumbRaw)
          : null,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      type: () {
        final url = normalizeUrl((json['url'] ?? '').toString());
        final t = rawType.toUpperCase();
        final isVideo = mime.startsWith('video/') || looksLikeVideo(url);
        final isImage = mime.startsWith('image/') || looksLikeImage(url);

        if (isVideo) return 'VIDEO';
        if (isImage) return 'IMAGE';
        if (t.isEmpty) return 'FILE';
        if (t == 'FILE' && looksLikeVideo(url)) return 'VIDEO';
        return t;
      }(),
    );
  }
}

class PostAuthorModel {
  final int id;
  final String name;
  final String? avatarUrl;

  PostAuthorModel({required this.id, required this.name, this.avatarUrl});

  factory PostAuthorModel.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] as Map<String, dynamic>?) ?? {};
    final avatarMedia = (profile['avatarMedia'] as Map<String, dynamic>?) ?? {};
    final displayName =
        (profile['displayName'] ?? profile['username'] ?? 'User').toString();
    final avatarUrl = (avatarMedia['url'] as String?)?.trim();
    return PostAuthorModel(
      id: (json['id'] as num).toInt(),
      name: displayName,
      avatarUrl: (avatarUrl == null || avatarUrl.isEmpty)
          ? null
          : MediaUrl.normalize(avatarUrl),
    );
  }
}

class PostTaggedPetModel {
  final int id;
  final String name;
  final String? photoUrl;

  PostTaggedPetModel({required this.id, required this.name, this.photoUrl});

  factory PostTaggedPetModel.fromJson(Map<String, dynamic> json) {
    final photo = (json['photo'] as Map<String, dynamic>?) ?? {};
    return PostTaggedPetModel(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? json['petName'] ?? 'Pet').toString(),
      photoUrl: (photo['url'] as String?)?.trim(),
    );
  }
}

class PostModel {
  final int id;
  final String type; // TEXT / IMAGE / VIDEO / REEL
  final String category; // GENERAL / FUNDRAISING
  final int? fundraisingCampaignId;
  final FundraisingEmbedModel? fundraisingEmbed;
  final String? caption;
  final String? context;
  final DateTime createdAt;
  final PostAuthorModel author;
  final List<PostMediaModel> media;
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe;
  final bool isBookmarkedByMe;
  final String privacy;
  final String? backgroundStyle;
  final String? feelingId;
  final String? feelingLabel;
  final String? feelingEmoji;
  final String? activityId;
  final String? activityLabel;
  final String? activityEmoji;

  // Premium social fields
  final int shareCount;
  final int viewCount;
  final bool isReportedByMe;
  final bool isFollowingAuthor;
  final String? sponsoredLabel;
  final String? locationTag;

  // Pet-focused post type fields
  final String?
  postType; // GENERAL / HEALTH_UPDATE / VACCINATION / LOST_PET / ADOPTION / SERVICE_REVIEW
  final String? lostPetName;
  final String? lostPetLocation;
  final bool lostPetContactVisible;
  final List<int> taggedPetIds;
  final List<PostTaggedPetModel> taggedPets;

  // Song metadata
  final String? songTitle;
  final String? songArtist;
  final int? songStartMs;
  final int? songDurationMs;

  PostModel({
    required this.id,
    required this.type,
    this.category = 'GENERAL',
    this.fundraisingCampaignId,
    this.fundraisingEmbed,
    this.caption,
    this.context,
    required this.createdAt,
    required this.author,
    required this.media,
    required this.likeCount,
    required this.commentCount,
    required this.isLikedByMe,
    this.isBookmarkedByMe = false,
    this.privacy = 'PUBLIC',
    this.backgroundStyle,
    this.feelingId,
    this.feelingLabel,
    this.feelingEmoji,
    this.activityId,
    this.activityLabel,
    this.activityEmoji,
    this.shareCount = 0,
    this.viewCount = 0,
    this.isReportedByMe = false,
    this.isFollowingAuthor = false,
    this.sponsoredLabel,
    this.locationTag,
    this.postType,
    this.lostPetName,
    this.lostPetLocation,
    this.lostPetContactVisible = false,
    this.taggedPetIds = const [],
    this.taggedPets = const [],
    this.songTitle,
    this.songArtist,
    this.songStartMs,
    this.songDurationMs,
  });

  bool get isVideo =>
      type == 'VIDEO' ||
      type == 'REEL' ||
      media.any((m) => m.type.toUpperCase() == 'VIDEO');

  static int? _parseIntValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }

  static int _readCount(
    Map<String, dynamic> counts,
    Map<String, dynamic> json,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = counts[key] ?? json[key];
      final parsed = _parseIntValue(value);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static String? _normalizePostType(
    dynamic raw, {
    bool hasLostPetMetadata = false,
  }) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) {
      return hasLostPetMetadata ? 'LOST_PET' : 'GENERAL';
    }

    final upper = value
        .replaceAll(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toUpperCase();

    switch (upper) {
      case 'GENERAL':
      case 'GENERAL_POST':
        return 'GENERAL';
      case 'HEALTH_UPDATE':
      case 'VACCINATION':
      case 'LOST_PET':
      case 'ADOPTION':
      case 'SERVICE_REVIEW':
        return upper;
      default:
        if (hasLostPetMetadata &&
            upper.contains('LOST') &&
            upper.contains('PET')) {
          return 'LOST_PET';
        }
        return upper;
    }
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final authorJson = (json['author'] as Map<String, dynamic>?);
    final mediaJson = (json['media'] as List?) ?? const [];
    final countJson = (json['_count'] as Map<String, dynamic>?) ?? {};

    final fundraisingRaw =
        (json['fundraisingCampaign'] as Map<String, dynamic>?);
    final fundraisingId = (fundraisingRaw?['id'] as num?)?.toInt();
    final hasMoreThanId =
        fundraisingRaw != null && (fundraisingRaw.keys.length > 1);
    final embed = (fundraisingId != null && hasMoreThanId)
        ? FundraisingEmbedModel.fromJson(fundraisingRaw)
        : null;

    // Parse tagged pets
    final taggedPetsRaw = (json['taggedPets'] as List?) ?? const [];
    final taggedPets = taggedPetsRaw
        .map((e) => PostTaggedPetModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final taggedPetIdsRaw = (json['taggedPetIds'] as List?) ?? const [];
    final taggedPetIds = <int>{
      for (final pet in taggedPets) pet.id,
      for (final raw in taggedPetIdsRaw)
        if (_parseIntValue(raw) != null) _parseIntValue(raw)!,
    }.toList();

    // Parse lost pet details (nested or flat)
    final lostPetRaw = (json['lostPetDetails'] is Map)
        ? Map<String, dynamic>.from(json['lostPetDetails'] as Map)
        : const <String, dynamic>{};
    final lostPetName =
        (lostPetRaw['petName'] ?? json['lostPetName'] as String?)?.toString();
    final lostPetLocation =
        (lostPetRaw['lastSeenLocation'] ?? json['lostPetLocation'] as String?)
            ?.toString();
    final hasLostPetMetadata =
        (lostPetName?.trim().isNotEmpty ?? false) ||
        (lostPetLocation?.trim().isNotEmpty ?? false) ||
        lostPetRaw.isNotEmpty;
    final normalizedPostType = _normalizePostType(
      json['postType'],
      hasLostPetMetadata: hasLostPetMetadata,
    );
    final feeling = (json['feeling'] is Map)
        ? Map<String, dynamic>.from(json['feeling'] as Map)
        : const <String, dynamic>{};
    final activity = (json['activity'] is Map)
        ? Map<String, dynamic>.from(json['activity'] as Map)
        : const <String, dynamic>{};
    final locationText = (json['locationText'] ?? json['locationTag'])
        ?.toString()
        .trim();

    return PostModel(
      id: (json['id'] as num).toInt(),
      type: (json['type'] ?? 'TEXT').toString(),
      category: (json['category'] ?? 'GENERAL').toString(),
      fundraisingCampaignId: fundraisingId,
      fundraisingEmbed: embed,
      caption: (json['caption'] as String?)?.trim(),
      context: (json['context'] as String?)?.trim(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      author: PostAuthorModel.fromJson(
        authorJson ??
            const {
              'id': 0,
              'profile': {'displayName': 'User'},
            },
      ),
      media: mediaJson
          .map((e) {
            final map = (e as Map<String, dynamic>);
            final m = (map['media'] as Map<String, dynamic>?);
            return m == null ? null : PostMediaModel.fromJson(m);
          })
          .whereType<PostMediaModel>()
          .toList(),
      likeCount: _readCount(countJson, json, const [
        'likes',
        'likeCount',
        'pawCount',
        'paws',
      ]),
      commentCount: _readCount(countJson, json, const [
        'comments',
        'commentCount',
      ]),
      isLikedByMe:
          (json['isLikedByMe'] as bool?) ??
          (json['isLiked'] as bool?) ??
          (json['isPawed'] as bool?) ??
          false,
      isBookmarkedByMe: (json['isBookmarkedByMe'] as bool?) ?? false,
      privacy: (json['privacy'] ?? 'PUBLIC').toString(),
      backgroundStyle: json['backgroundStyle']?.toString(),
      feelingId: (feeling['id'] ?? json['feelingId'])?.toString(),
      feelingLabel: (feeling['label'] ?? json['feelingLabel'])?.toString(),
      feelingEmoji: (feeling['emoji'] ?? json['feelingEmoji'])?.toString(),
      activityId: (activity['id'] ?? json['activityId'])?.toString(),
      activityLabel: (activity['label'] ?? json['activityLabel'])?.toString(),
      activityEmoji: (activity['emoji'] ?? json['activityEmoji'])?.toString(),
      shareCount: _readCount(
        const <String, dynamic>{},
        json,
        const ['shareCount', 'sharesCount'],
      ),
      viewCount: _readCount(
        const <String, dynamic>{},
        json,
        const ['viewCount', 'viewsCount'],
      ),
      isReportedByMe: (json['isReportedByMe'] as bool?) ?? false,
      isFollowingAuthor: (json['isFollowingAuthor'] as bool?) ?? false,
      sponsoredLabel: json['sponsoredLabel']?.toString(),
      locationTag: locationText,
      // Pet-focused fields (safe when null for old posts)
      postType: normalizedPostType,
      lostPetName: lostPetName,
      lostPetLocation: lostPetLocation,
      lostPetContactVisible:
          (lostPetRaw['contactVisible'] ??
              json['lostPetContactVisible'] as bool?) ??
          false,
      taggedPetIds: taggedPetIds,
      taggedPets: taggedPets,
      songTitle: json['songTitle']?.toString(),
      songArtist: json['songArtist']?.toString(),
      songStartMs: _parseIntValue(json['songStartMs']),
      songDurationMs: _parseIntValue(json['songDurationMs']),
    );
  }

  PostModel copyWith({
    int? id,
    String? type,
    String? category,
    int? fundraisingCampaignId,
    FundraisingEmbedModel? fundraisingEmbed,
    String? caption,
    String? context,
    DateTime? createdAt,
    PostAuthorModel? author,
    List<PostMediaModel>? media,
    int? likeCount,
    int? commentCount,
    bool? isLikedByMe,
    bool? isBookmarkedByMe,
    String? privacy,
    String? backgroundStyle,
    String? feelingId,
    String? feelingLabel,
    String? feelingEmoji,
    String? activityId,
    String? activityLabel,
    String? activityEmoji,
    int? shareCount,
    int? viewCount,
    bool? isReportedByMe,
    bool? isFollowingAuthor,
    String? sponsoredLabel,
    String? locationTag,
    String? postType,
    String? lostPetName,
    String? lostPetLocation,
    bool? lostPetContactVisible,
    List<int>? taggedPetIds,
    List<PostTaggedPetModel>? taggedPets,
    String? songTitle,
    String? songArtist,
    int? songStartMs,
    int? songDurationMs,
  }) {
    return PostModel(
      id: id ?? this.id,
      type: type ?? this.type,
      category: category ?? this.category,
      fundraisingCampaignId:
          fundraisingCampaignId ?? this.fundraisingCampaignId,
      fundraisingEmbed: fundraisingEmbed ?? this.fundraisingEmbed,
      caption: caption ?? this.caption,
      context: context ?? this.context,
      createdAt: createdAt ?? this.createdAt,
      author: author ?? this.author,
      media: media ?? this.media,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isBookmarkedByMe: isBookmarkedByMe ?? this.isBookmarkedByMe,
      privacy: privacy ?? this.privacy,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      feelingId: feelingId ?? this.feelingId,
      feelingLabel: feelingLabel ?? this.feelingLabel,
      feelingEmoji: feelingEmoji ?? this.feelingEmoji,
      activityId: activityId ?? this.activityId,
      activityLabel: activityLabel ?? this.activityLabel,
      activityEmoji: activityEmoji ?? this.activityEmoji,
      shareCount: shareCount ?? this.shareCount,
      viewCount: viewCount ?? this.viewCount,
      isReportedByMe: isReportedByMe ?? this.isReportedByMe,
      isFollowingAuthor: isFollowingAuthor ?? this.isFollowingAuthor,
      sponsoredLabel: sponsoredLabel ?? this.sponsoredLabel,
      locationTag: locationTag ?? this.locationTag,
      postType: postType ?? this.postType,
      lostPetName: lostPetName ?? this.lostPetName,
      lostPetLocation: lostPetLocation ?? this.lostPetLocation,
      lostPetContactVisible:
          lostPetContactVisible ?? this.lostPetContactVisible,
      taggedPetIds: taggedPetIds ?? this.taggedPetIds,
      taggedPets: taggedPets ?? this.taggedPets,
      songTitle: songTitle ?? this.songTitle,
      songArtist: songArtist ?? this.songArtist,
      songStartMs: songStartMs ?? this.songStartMs,
      songDurationMs: songDurationMs ?? this.songDurationMs,
    );
  }
}
