/// Aggregated campaign performance metrics (local + optional server).
class CampaignPerformanceMetrics {
  final String slug;
  final int views;
  final int clicks;
  final int bookings;
  final num revenue;
  final String? abVariant;

  const CampaignPerformanceMetrics({
    required this.slug,
    this.views = 0,
    this.clicks = 0,
    this.bookings = 0,
    this.revenue = 0,
    this.abVariant,
  });

  double get clickThroughRate => views == 0 ? 0 : clicks / views;
  double get bookingRate => clicks == 0 ? 0 : bookings / clicks;
  double get paymentConversionRate => bookings == 0 ? 0 : revenue > 0 ? 1.0 : 0.0;
  double get conversionRate => views == 0 ? 0 : bookings / views;

  CampaignPerformanceMetrics copyWith({
    int? views,
    int? clicks,
    int? bookings,
    num? revenue,
  }) {
    return CampaignPerformanceMetrics(
      slug: slug,
      views: views ?? this.views,
      clicks: clicks ?? this.clicks,
      bookings: bookings ?? this.bookings,
      revenue: revenue ?? this.revenue,
      abVariant: abVariant,
    );
  }

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'views': views,
        'clicks': clicks,
        'bookings': bookings,
        'revenue': revenue,
        'abVariant': abVariant,
      };

  factory CampaignPerformanceMetrics.fromJson(Map<String, dynamic> json) {
    return CampaignPerformanceMetrics(
      slug: json['slug']?.toString() ?? '',
      views: json['views'] is int ? json['views'] as int : int.tryParse('${json['views']}') ?? 0,
      clicks: json['clicks'] is int ? json['clicks'] as int : int.tryParse('${json['clicks']}') ?? 0,
      bookings: json['bookings'] is int ? json['bookings'] as int : int.tryParse('${json['bookings']}') ?? 0,
      revenue: json['revenue'] is num ? json['revenue'] as num : num.tryParse('${json['revenue']}') ?? 0,
      abVariant: json['abVariant']?.toString(),
    );
  }
}
