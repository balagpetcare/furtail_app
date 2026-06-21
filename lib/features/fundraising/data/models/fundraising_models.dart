import 'package:bpa_app/core/media/media_url.dart';

class FundraisingAuthor {
  final int id;
  final String displayName;
  final String? username;
  final String? avatarUrl;

  const FundraisingAuthor({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
  });

  factory FundraisingAuthor.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] is Map)
        ? Map<String, dynamic>.from(json['profile'])
        : const <String, dynamic>{};
    final avatarMedia = (profile['avatarMedia'] is Map)
        ? Map<String, dynamic>.from(profile['avatarMedia'])
        : const <String, dynamic>{};
    return FundraisingAuthor(
      id: (json['id'] as num?)?.toInt() ?? 0,
      displayName: (profile['displayName'] ?? 'BPA Member').toString(),
      username: profile['username']?.toString(),
      avatarUrl: (() {
        final u = avatarMedia['url']?.toString() ?? '';
        if (u.trim().isEmpty) return null;
        return MediaUrl.normalize(u);
      })(),
    );
  }
}

class FundraisingMediaItem {
  final int id;
  final String url;
  final String type;

  const FundraisingMediaItem({
    required this.id,
    required this.url,
    required this.type,
  });

  factory FundraisingMediaItem.fromJson(Map<String, dynamic> json) {
    return FundraisingMediaItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      url: MediaUrl.normalize((json['url'] ?? '').toString()),
      type: (json['type'] ?? '').toString(),
    );
  }
}

class FundraisingStats {
  final int raisedAmount;
  final int withdrawnAmount;
  final int donorsCount;

  const FundraisingStats({
    required this.raisedAmount,
    required this.withdrawnAmount,
    required this.donorsCount,
  });

  factory FundraisingStats.fromJson(Map<String, dynamic> json) {
    return FundraisingStats(
      raisedAmount: (json['raisedAmount'] as num?)?.toInt() ?? 0,
      withdrawnAmount: (json['withdrawnAmount'] as num?)?.toInt() ?? 0,
      donorsCount: (json['donorsCount'] as num?)?.toInt() ?? 0,
    );
  }

  int get availableAmount => (raisedAmount - withdrawnAmount).clamp(0, 1 << 30);
}

class FundraisingDonor {
  final int id;
  final String name;
  final String? avatarUrl;
  final int? amount;

  const FundraisingDonor({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.amount,
  });

  factory FundraisingDonor.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] is Map)
        ? Map<String, dynamic>.from(json['profile'])
        : const <String, dynamic>{};
    final avatarMedia = (profile['avatarMedia'] is Map)
        ? Map<String, dynamic>.from(profile['avatarMedia'])
        : const <String, dynamic>{};
    return FundraisingDonor(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (profile['displayName'] ?? 'BPA Member').toString(),
      avatarUrl: (() {
        final u = avatarMedia['url']?.toString() ?? '';
        if (u.trim().isEmpty) return null;
        return MediaUrl.normalize(u);
      })(),
      amount: (json['amount'] as num?)?.toInt(),
    );
  }
}

class FundraisingAccountDocument {
  final int id;
  final String title;
  final String? mediaUrl;

  const FundraisingAccountDocument({
    required this.id,
    required this.title,
    required this.mediaUrl,
  });

  factory FundraisingAccountDocument.fromJson(Map<String, dynamic> json) {
    final media = (json['media'] is Map)
        ? Map<String, dynamic>.from(json['media'])
        : const <String, dynamic>{};
    final u = media['url']?.toString() ?? '';
    return FundraisingAccountDocument(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? 'Document').toString(),
      mediaUrl: u.trim().isEmpty ? null : MediaUrl.normalize(u),
    );
  }
}

class FundraisingAccount {
  final int id;
  final String status; // DRAFT/PENDING/VERIFIED/REJECTED
  final String accountType; // INDIVIDUAL/ORGANIZATION
  final String? presentAddress;
  final String? permanentAddress;
  final String? occupation;
  final int? divisionId;
  final int? districtId;
  final int? upazilaId;
  final int? unionId;
  final int? areaId;
  final DateTime? dateOfBirth;
  final String? nationalIdNumber;
  final String? birthRegNumber;
  final String? studentIdNumber;
  final String? area;
  final int? rescueSinceYear;
  final String? orgName;
  final String? orgDescription;
  final String? orgWorkType;
  final DateTime? submittedAt;
  final List<FundraisingAccountDocument> documents;

  // Global location (Phase 5)
  final String? countryCode;
  final String? countryName;
  final String? stateName;
  final String? cityName;
  final String? addressLine;
  final double? latitude;
  final double? longitude;
  final String? formattedAddress;

  const FundraisingAccount({
    required this.id,
    required this.status,
    required this.accountType,
    required this.presentAddress,
    required this.permanentAddress,
    required this.occupation,
    required this.divisionId,
    required this.districtId,
    required this.upazilaId,
    required this.unionId,
    required this.areaId,
    required this.dateOfBirth,
    required this.nationalIdNumber,
    required this.birthRegNumber,
    required this.studentIdNumber,
    required this.area,
    required this.rescueSinceYear,
    required this.orgName,
    required this.orgDescription,
    required this.orgWorkType,
    required this.submittedAt,
    required this.documents,
    this.countryCode,
    this.countryName,
    this.stateName,
    this.cityName,
    this.addressLine,
    this.latitude,
    this.longitude,
    this.formattedAddress,
  });

  factory FundraisingAccount.fromJson(Map<String, dynamic> json) {
    final docsRaw = (json['documents'] as List?) ?? const [];
    final docs = docsRaw
        .whereType<Map>()
        .map((e) => FundraisingAccountDocument.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList();

    DateTime? submittedAt;
    final s = json['submittedAt']?.toString();
    if (s != null && s.isNotEmpty) submittedAt = DateTime.tryParse(s);

    return FundraisingAccount(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'DRAFT').toString(),
      accountType: (json['accountType'] ?? 'INDIVIDUAL').toString(),
      presentAddress: json['presentAddress']?.toString(),
      permanentAddress: json['permanentAddress']?.toString(),
      occupation: json['occupation']?.toString(),
      divisionId: (json['divisionId'] as num?)?.toInt(),
      districtId: (json['districtId'] as num?)?.toInt(),
      upazilaId: (json['upazilaId'] as num?)?.toInt(),
      unionId: (json['unionId'] as num?)?.toInt(),
      areaId: (json['areaId'] as num?)?.toInt(),
      dateOfBirth: (() { final s = json['dateOfBirth']?.toString(); return (s == null || s.isEmpty) ? null : DateTime.tryParse(s); })(),
      nationalIdNumber: json['nationalIdNumber']?.toString(),
      birthRegNumber: json['birthRegNumber']?.toString(),
      studentIdNumber: json['studentIdNumber']?.toString(),
      area: json['area']?.toString(),
      rescueSinceYear: (json['rescueSinceYear'] as num?)?.toInt(),
      orgName: json['orgName']?.toString(),
      orgDescription: json['orgDescription']?.toString(),
      orgWorkType: json['orgWorkType']?.toString(),
      submittedAt: submittedAt,
      documents: docs,
      countryCode: json['countryCode']?.toString(),
      countryName: json['countryName']?.toString(),
      stateName: json['stateName']?.toString(),
      cityName: json['cityName']?.toString(),
      addressLine: json['addressLine']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      formattedAddress: json['formattedAddress']?.toString(),
    );
  }

  bool get isVerified => status.toUpperCase() == 'VERIFIED';
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
}

class FundraisingCampaign {
  final int id;
  final int postId;
  final String title;
  final int targetAmount;
  final DateTime? deadline;
  final DateTime createdAt;
  final String status;
  final FundraisingAuthor author;
  final String? caption;
  final List<FundraisingMediaItem> media;
  final FundraisingStats stats;
  final bool isAccountVerified;
  final String? category;
  final String? locationText;
  final List<FundraisingDonor> last3Donors;

  const FundraisingCampaign({
    required this.id,
    required this.postId,
    required this.title,
    required this.targetAmount,
    required this.deadline,
    required this.createdAt,
    required this.status,
    required this.author,
    required this.caption,
    required this.media,
    required this.stats,
    required this.isAccountVerified,
    required this.category,
    required this.locationText,
    required this.last3Donors,
  });

  factory FundraisingCampaign.fromJson(Map<String, dynamic> json) {
    final post = (json['post'] is Map)
        ? Map<String, dynamic>.from(json['post'])
        : const <String, dynamic>{};
    final authorJson = (post['author'] is Map)
        ? Map<String, dynamic>.from(post['author'])
        : const <String, dynamic>{};
    final statsJson = (json['stats'] is Map)
        ? Map<String, dynamic>.from(json['stats'])
        : const <String, dynamic>{};
    final account = (json['account'] is Map)
        ? Map<String, dynamic>.from(json['account'])
        : const <String, dynamic>{};

    final last3 = (json['last3Donors'] as List?) ?? const [];
    final last3Donors = last3
        .whereType<Map>()
        .map((e) => FundraisingDonor.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final mediaRaw = (post['media'] as List?) ?? const [];
    final media = mediaRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map((pm) {
          final m = (pm['media'] is Map)
              ? Map<String, dynamic>.from(pm['media'])
              : const <String, dynamic>{};
          return FundraisingMediaItem.fromJson(m);
        })
        .toList();

    DateTime? deadline;
    final dl = json['deadline']?.toString();
    if (dl != null && dl.isNotEmpty) {
      deadline = DateTime.tryParse(dl);
    }

    final createdAtRaw = post['createdAt']?.toString();
    final createdAt = (createdAtRaw != null && createdAtRaw.isNotEmpty)
        ? (DateTime.tryParse(createdAtRaw) ?? DateTime.now())
        : DateTime.now();

    return FundraisingCampaign(
      id: (json['id'] as num?)?.toInt() ?? 0,
      postId: (post['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? 'Campaign').toString(),
      targetAmount: (json['targetAmount'] as num?)?.toInt() ?? 0,
      deadline: deadline,
      createdAt: createdAt,
      status: (json['status'] ?? 'ACTIVE').toString(),
      author: FundraisingAuthor.fromJson(authorJson),
      caption: post['caption']?.toString(),
      media: media,
      stats: FundraisingStats.fromJson(statsJson),
      isAccountVerified:
          (account['status']?.toString().toUpperCase() == 'VERIFIED'),
      category: json['category']?.toString(),
      locationText: json['locationText']?.toString(),
      last3Donors: last3Donors,
    );
  }

  int get remainingAmount {
    final r = targetAmount - stats.raisedAmount;
    return r < 0 ? 0 : r;
  }

  double get progress {
    if (targetAmount <= 0) return 0;
    final p = stats.raisedAmount / targetAmount;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  String? get context => null;

  int? get remainingDays {
    if (deadline == null) return null;
    final now = DateTime.now();
    final d = deadline!;
    final diff = d.difference(DateTime(now.year, now.month, now.day));
    return diff.inDays;
  }
}

class DonationItem {
  final int id;
  final int amount;
  final DateTime createdAt;
  final FundraisingDonor donor;

  const DonationItem({
    required this.id,
    required this.amount,
    required this.createdAt,
    required this.donor,
  });

  factory DonationItem.fromJson(Map<String, dynamic> json) {
    final donorJson = (json['donor'] is Map)
        ? Map<String, dynamic>.from(json['donor'])
        : const <String, dynamic>{};
    final created = DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now();
    return DonationItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      createdAt: created,
      donor: FundraisingDonor.fromJson(donorJson),
    );
  }
}

class FundraisingUpdateItem {
  final int id;
  final int postId;
  final DateTime createdAt;
  final String? caption;
  final FundraisingAuthor author;
  final List<FundraisingMediaItem> media;

  const FundraisingUpdateItem({
    required this.id,
    required this.postId,
    required this.createdAt,
    required this.caption,
    required this.author,
    required this.media,
  });

  factory FundraisingUpdateItem.fromJson(Map<String, dynamic> json) {
    final post = (json['post'] is Map)
        ? Map<String, dynamic>.from(json['post'])
        : const <String, dynamic>{};
    final authorJson = (post['author'] is Map)
        ? Map<String, dynamic>.from(post['author'])
        : const <String, dynamic>{};
    final mediaRaw = (post['media'] as List?) ?? const [];
    final media = mediaRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map((pm) {
          final m = (pm['media'] is Map)
              ? Map<String, dynamic>.from(pm['media'])
              : const <String, dynamic>{};
          return FundraisingMediaItem.fromJson(m);
        })
        .toList();
    final createdAt = DateTime.tryParse((json['createdAt'] ?? post['createdAt'] ?? '').toString()) ?? DateTime.now();
    return FundraisingUpdateItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      postId: (post['id'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
      caption: post['caption']?.toString(),
      author: FundraisingAuthor.fromJson(authorJson),
      media: media,
    );
  }
}
