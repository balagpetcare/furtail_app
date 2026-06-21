class FundraisingCampaign {
  final int id;
  final String title;
  final String? caption;
  final int targetAmount;
  final DateTime deadline;
  final String? category;
  final String? locationText;
  final String status;

  final int raisedAmount;
  final int donorCount;
  final int updateCount;
  final int? likeCount;
  final int? commentCount;
  final int? shareCount;

  final List<LastDonor> last3Donors;

  /// Post media (images/videos) - keep generic so it matches your existing API
  final List<Map<String, dynamic>> media;

  FundraisingCampaign({
    required this.id,
    required this.title,
    required this.caption,
    required this.targetAmount,
    required this.deadline,
    required this.category,
    required this.locationText,
    required this.status,
    required this.raisedAmount,
    required this.donorCount,
    required this.updateCount,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.last3Donors,
    required this.media,
  });

  static FundraisingCampaign fromJson(Map<String, dynamic> json) {
    final stats = (json['stats'] as Map<String, dynamic>?) ?? const {};
    return FundraisingCampaign(
      id: json['id'] as int,
      title: (json['title'] ?? '') as String,
      caption: json['caption'] as String?,
      targetAmount: (json['targetAmount'] ?? 0) as int,
      deadline: DateTime.parse(json['deadline'] as String),
      category: json['category'] as String?,
      locationText: json['locationText'] as String?,
      status: (json['status'] ?? 'ACTIVE') as String,
      raisedAmount: (stats['raisedAmount'] ?? 0) as int,
      donorCount: (stats['donorCount'] ?? 0) as int,
      updateCount: (stats['updateCount'] ?? 0) as int,
      likeCount: json['likeCount'] as int?,
      commentCount: json['commentCount'] as int?,
      shareCount: json['shareCount'] as int?,
      last3Donors: ((json['last3Donors'] as List?) ?? const [])
          .map((e) => LastDonor.fromJson(e as Map<String, dynamic>))
          .toList(),
      media: ((json['media'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
    );
  }
}

class LastDonor {
  final int id;
  final String name;
  final String? avatarUrl;
  final int amount;
  final DateTime createdAt;

  LastDonor({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.amount,
    required this.createdAt,
  });

  static LastDonor fromJson(Map<String, dynamic> json) {
    return LastDonor(
      id: (json['id'] ?? 0) as int,
      name: ((json['name'] ?? json['fullName'] ?? 'Donor') as String),
      avatarUrl: json['avatarUrl'] as String?,
      amount: (json['amount'] ?? 0) as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class DonationItem {
  final int id;
  final int amount;
  final DateTime createdAt;
  final String donorName;
  final String? donorAvatarUrl;

  DonationItem({
    required this.id,
    required this.amount,
    required this.createdAt,
    required this.donorName,
    required this.donorAvatarUrl,
  });

  static DonationItem fromJson(Map<String, dynamic> json) {
    final donor = (json['donor'] as Map<String, dynamic>?) ?? const {};
    return DonationItem(
      id: json['id'] as int,
      amount: (json['amount'] ?? 0) as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      donorName: ((donor['name'] ?? donor['fullName'] ?? 'Donor') as String),
      donorAvatarUrl: donor['avatarUrl'] as String?,
    );
  }
}

class FundraisingUpdateItem {
  final int id;
  final String text;
  final DateTime createdAt;

  /// optional attached media / document
  final Map<String, dynamic>? attachment;

  FundraisingUpdateItem({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.attachment,
  });

  static FundraisingUpdateItem fromJson(Map<String, dynamic> json) {
    return FundraisingUpdateItem(
      id: json['id'] as int,
      text: (json['text'] ?? '') as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      attachment: (json['attachment'] as Map?)?.cast<String, dynamic>(),
    );
  }
}
