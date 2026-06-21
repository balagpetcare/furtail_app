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

    // stats can be nested (stats.raisedAmount) or flattened (raisedAmount)
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
      raisedAmount: (stats['raisedAmount'] as num?)?.toInt() ??
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
  final String type; // IMAGE / VIDEO

  PostMediaModel({required this.id, required this.url, required this.type});

  factory PostMediaModel.fromJson(Map<String, dynamic> json) {
    bool _looksLikeVideo(String url) {
      final u = url.toLowerCase();
      return RegExp(r'\.(mp4|mov|m4v|webm|mkv|avi)(\?|$)').hasMatch(u);
    }

    bool _looksLikeImage(String url) {
      final u = url.toLowerCase();
      return RegExp(r'\.(png|jpe?g|gif|webp)(\?|$)').hasMatch(u);
    }

    String normalizeUrl(String raw) => MediaUrl.normalize(raw);

    // Some older backend builds stored videos as FILE, or omitted type.
    // Infer a usable type from mimeType and/or the URL extension so the feed
    // renders a proper in-app player instead of an external link.
    final rawType = (json['type'] ?? '').toString().trim();
    final mime =
        (json['mimeType'] ?? json['mimetype'] ?? '').toString().toLowerCase();

    return PostMediaModel(
      id: (json['id'] as num).toInt(),
      url: normalizeUrl((json['url'] ?? '').toString()),
      type: () {
        final url = normalizeUrl((json['url'] ?? '').toString());
        final t = rawType.toUpperCase();
        final isVideo = mime.startsWith('video/') || _looksLikeVideo(url);
        final isImage = mime.startsWith('image/') || _looksLikeImage(url);

        if (isVideo) return 'VIDEO';
        if (isImage) return 'IMAGE';
        if (t.isEmpty) return 'FILE';
        // If backend returns FILE for video, upgrade it.
        if (t == 'FILE' && _looksLikeVideo(url)) return 'VIDEO';
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
    // avatarMedia can be missing for many users; avoid null-assertion crashes.
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

class PostModel {
  final int id;
  final String type; // TEXT / IMAGE / VIDEO / REEL
  /// Post category.
  /// Kept as String to match backend enum values (e.g. GENERAL/FUNDRAISING).
  /// Default provided to keep backward compatibility with older UI code.
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
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final authorJson = (json['author'] as Map<String, dynamic>?);
    final mediaJson = (json['media'] as List?) ?? const [];
    final countJson = (json['_count'] as Map<String, dynamic>?) ?? {};

    final fundraisingRaw = (json['fundraisingCampaign'] as Map<String, dynamic>?);
    final fundraisingId = (fundraisingRaw?['id'] as num?)?.toInt();
    // If backend includes more fields than id, we parse it as embedded summary.
    final hasMoreThanId =
        fundraisingRaw != null && (fundraisingRaw.keys.length > 1);
    final embed = (fundraisingId != null && hasMoreThanId)
        ? FundraisingEmbedModel.fromJson(fundraisingRaw)
        : null;
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
      likeCount: ((countJson['likes'] as num?) ?? 0).toInt(),
      commentCount: ((countJson['comments'] as num?) ?? 0).toInt(),
      isLikedByMe: (json['isLikedByMe'] as bool?) ?? false,
    );
  }

  bool get isVideo =>
      type == 'VIDEO' ||
      type == 'REEL' ||
      media.any((m) => m.type.toUpperCase() == 'VIDEO');
}
