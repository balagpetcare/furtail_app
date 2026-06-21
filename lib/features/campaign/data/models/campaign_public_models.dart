import 'campaign_models.dart';
import '../../domain/smart_campaign/campaign_ab_variant.dart';
import '../../domain/smart_campaign/smart_campaign_config.dart';

/// Active public vaccination campaign.
class PublicCampaign {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String pricingType;
  final num? priceAmount;
  final String currency;
  final int maxPetsPerBooking;
  final List<PublicCampaignLocation> locations;
  final List<String> packageFeatures;
  final PublicCampaignPricing? pricing;
  final PublicCampaignConfig? config;
  final String? imageUrl;
  final int? remainingSlots;
  final String? nextSlotDate;
  final String? primaryLocationLabel;
  final SmartCampaignConfig smartConfig;
  final CampaignAbVariant? abVariant;

  const PublicCampaign({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.pricingType,
    this.priceAmount,
    this.currency = 'BDT',
    this.maxPetsPerBooking = 5,
    this.locations = const [],
    this.packageFeatures = const [],
    this.pricing,
    this.config,
    this.imageUrl,
    this.remainingSlots,
    this.nextSlotDate,
    this.primaryLocationLabel,
    this.smartConfig = const SmartCampaignConfig(),
    this.abVariant,
  });

  bool get isFree =>
      pricingType == 'FREE' || pricing?.isFree == true || (priceAmount ?? 0) <= 0;

  String get displayPrice {
    if (isFree) return 'Free';
    final amount = pricing?.totalPrice ?? priceAmount;
    if (amount == null) return 'Paid';
    return '৳${amount is int ? amount : amount.toStringAsFixed(0)}';
  }

  PublicCampaign copyWith({
    int? remainingSlots,
    String? nextSlotDate,
    String? primaryLocationLabel,
    String? imageUrl,
    SmartCampaignConfig? smartConfig,
    CampaignAbVariant? abVariant,
  }) {
    return PublicCampaign(
      id: id,
      name: name,
      slug: slug,
      description: description,
      startDate: startDate,
      endDate: endDate,
      pricingType: pricingType,
      priceAmount: priceAmount,
      currency: currency,
      maxPetsPerBooking: maxPetsPerBooking,
      locations: locations,
      packageFeatures: packageFeatures,
      pricing: pricing,
      config: config,
      imageUrl: imageUrl ?? this.imageUrl,
      remainingSlots: remainingSlots ?? this.remainingSlots,
      nextSlotDate: nextSlotDate ?? this.nextSlotDate,
      primaryLocationLabel: primaryLocationLabel ?? this.primaryLocationLabel,
      smartConfig: smartConfig ?? this.smartConfig,
      abVariant: abVariant ?? this.abVariant,
    );
  }

  factory PublicCampaign.fromJson(Map<String, dynamic> json) {
    final locsRaw = json['locations'];
    final locations = locsRaw is List
        ? locsRaw
            .whereType<Map>()
            .map((e) => PublicCampaignLocation.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <PublicCampaignLocation>[];

    final featuresRaw = json['packageFeatures'];
    final features = featuresRaw is List
        ? featuresRaw.map((e) => e.toString()).toList()
        : <String>[];

    PublicCampaignPricing? pricing;
    if (json['pricing'] is Map) {
      pricing = PublicCampaignPricing.fromJson(
        Map<String, dynamic>.from(json['pricing'] as Map),
      );
    }

    PublicCampaignConfig? config;
    if (json['config'] is Map) {
      config = PublicCampaignConfig.fromJson(
        Map<String, dynamic>.from(json['config'] as Map),
      );
    }

    final metadata = json['metadataJson'];
    final smartConfig = SmartCampaignConfig.fromMetadata(metadata);

    return PublicCampaign(
      id: campaignJsonInt(json['id']),
      name: json['name']?.toString() ?? 'Campaign',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      startDate: campaignJsonDate(json['startDate']) ?? DateTime.now(),
      endDate: campaignJsonDate(json['endDate']) ?? DateTime.now(),
      pricingType: json['pricingType']?.toString() ?? 'FREE',
      priceAmount: json['priceAmount'] is num ? json['priceAmount'] as num : null,
      currency: json['currency']?.toString() ?? 'BDT',
      maxPetsPerBooking: campaignJsonInt(json['maxPetsPerBooking'], fallback: 5),
      locations: locations,
      packageFeatures: features,
      pricing: pricing,
      config: config,
      imageUrl: _mobileBannerUrl(metadata),
      primaryLocationLabel: locations.isEmpty
          ? null
          : locations.length == 1
              ? locations.first.name
              : '${locations.first.name} +${locations.length - 1}',
      smartConfig: smartConfig,
    );
  }

  static String? _mobileBannerUrl(dynamic metadataJson) {
    if (metadataJson is! Map) return null;
    final mobile = metadataJson['mobile'];
    if (mobile is Map) {
      final url = mobile['bannerImageUrl'] ?? mobile['imageUrl'];
      if (url != null && url.toString().isNotEmpty) return url.toString();
    }
    final direct = metadataJson['bannerImageUrl'] ?? metadataJson['mobileBannerUrl'];
    return direct?.toString();
  }

  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'pricingType': pricingType,
        'priceAmount': priceAmount,
        'currency': currency,
        'maxPetsPerBooking': maxPetsPerBooking,
        'locations': locations.map((e) => e.toCacheJson()).toList(),
        'packageFeatures': packageFeatures,
        'pricing': pricing?.toCacheJson(),
        'config': config?.toCacheJson(),
        'imageUrl': imageUrl,
        'remainingSlots': remainingSlots,
        'nextSlotDate': nextSlotDate,
        'primaryLocationLabel': primaryLocationLabel,
        'smartConfigType': smartConfig.campaignType.code,
        'priority': smartConfig.priority.code,
      };

  factory PublicCampaign.fromCacheJson(Map<String, dynamic> json) {
    return PublicCampaign.fromJson(json);
  }
}

class PublicCampaignPricing {
  final num vaccineCost;
  final num serviceCharge;
  final num totalPrice;
  final String currency;
  final bool isFree;

  const PublicCampaignPricing({
    required this.vaccineCost,
    required this.serviceCharge,
    required this.totalPrice,
    required this.currency,
    required this.isFree,
  });

  factory PublicCampaignPricing.fromJson(Map<String, dynamic> json) {
    return PublicCampaignPricing(
      vaccineCost: json['vaccineCost'] is num ? json['vaccineCost'] as num : 0,
      serviceCharge: json['serviceCharge'] is num ? json['serviceCharge'] as num : 0,
      totalPrice: json['totalPrice'] is num ? json['totalPrice'] as num : 0,
      currency: json['currency']?.toString() ?? 'BDT',
      isFree: json['isFree'] == true,
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'vaccineCost': vaccineCost,
        'serviceCharge': serviceCharge,
        'totalPrice': totalPrice,
        'currency': currency,
        'isFree': isFree,
      };
}

class PublicCampaignConfig {
  final bool bookingEnabled;
  final bool onlinePaymentEnabled;
  final bool payAtVenueEnabled;
  final bool slotRequired;
  final int maxCatsPerBooking;
  final bool showRemainingSlots;

  const PublicCampaignConfig({
    required this.bookingEnabled,
    required this.onlinePaymentEnabled,
    required this.payAtVenueEnabled,
    required this.slotRequired,
    required this.maxCatsPerBooking,
    required this.showRemainingSlots,
  });

  factory PublicCampaignConfig.fromJson(Map<String, dynamic> json) {
    return PublicCampaignConfig(
      bookingEnabled: json['bookingEnabled'] != false,
      onlinePaymentEnabled: json['onlinePaymentEnabled'] == true,
      payAtVenueEnabled: json['payAtVenueEnabled'] == true,
      slotRequired: json['slotRequired'] != false,
      maxCatsPerBooking: campaignJsonInt(json['maxCatsPerBooking'], fallback: 5),
      showRemainingSlots: json['showRemainingSlots'] != false,
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'bookingEnabled': bookingEnabled,
        'onlinePaymentEnabled': onlinePaymentEnabled,
        'payAtVenueEnabled': payAtVenueEnabled,
        'slotRequired': slotRequired,
        'maxCatsPerBooking': maxCatsPerBooking,
        'showRemainingSlots': showRemainingSlots,
      };
}

class PublicCampaignLocation {
  final int id;
  final String name;
  final String? address;
  final int dailyCapacity;
  final int availableCapacity;
  final bool isAvailable;
  final String? nextSlotDate;
  final int availableSlots;

  const PublicCampaignLocation({
    required this.id,
    required this.name,
    this.address,
    this.dailyCapacity = 0,
    this.availableCapacity = 0,
    this.isAvailable = true,
    this.nextSlotDate,
    this.availableSlots = 0,
  });

  factory PublicCampaignLocation.fromJson(Map<String, dynamic> json) {
    final remaining = json['remainingCapacity'] ?? json['availableCapacity'];
    return PublicCampaignLocation(
      id: campaignJsonInt(json['id']),
      name: json['name']?.toString() ?? 'Location',
      address: json['address']?.toString(),
      dailyCapacity: campaignJsonInt(json['dailyCapacity']),
      availableCapacity: campaignJsonInt(remaining),
      isAvailable: json['isAvailable'] != false,
      nextSlotDate: json['nextSlotDate']?.toString(),
      availableSlots: campaignJsonInt(json['availableSlots']),
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'name': name,
        'address': address,
        'dailyCapacity': dailyCapacity,
        'availableCapacity': availableCapacity,
        'isAvailable': isAvailable,
        'nextSlotDate': nextSlotDate,
        'availableSlots': availableSlots,
      };
}

class PublicCampaignSlot {
  final int slotId;
  final String date;
  final String startTime;
  final String endTime;
  final String? startTimeLabel;
  final String? endTimeLabel;
  final String? sessionName;
  final int capacity;
  final int bookedCount;
  final int availableCount;
  final String status;

  const PublicCampaignSlot({
    required this.slotId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.startTimeLabel,
    this.endTimeLabel,
    this.sessionName,
    required this.capacity,
    required this.bookedCount,
    required this.availableCount,
    required this.status,
  });

  String get displayTime =>
      startTimeLabel != null && endTimeLabel != null
          ? '$startTimeLabel – $endTimeLabel'
          : '$startTime – $endTime';

  factory PublicCampaignSlot.fromJson(Map<String, dynamic> json) {
    return PublicCampaignSlot(
      slotId: campaignJsonInt(json['slotId'] ?? json['id']),
      date: json['date']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      startTimeLabel: json['startTimeLabel']?.toString(),
      endTimeLabel: json['endTimeLabel']?.toString(),
      sessionName: json['sessionName']?.toString(),
      capacity: campaignJsonInt(json['capacity']),
      bookedCount: campaignJsonInt(json['bookedCount']),
      availableCount: campaignJsonInt(json['availableCount'] ?? json['remainingCapacity']),
      status: json['status']?.toString() ?? 'OPEN',
    );
  }
}

/// Campaign-related push/local notification payload.
class PublicCampaignNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? campaignSlug;
  final int? campaignId;
  final String? bookingRef;
  final String? actionUrl;
  final DateTime? scheduledAt;
  final bool read;

  const PublicCampaignNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.campaignSlug,
    this.campaignId,
    this.bookingRef,
    this.actionUrl,
    this.scheduledAt,
    this.read = false,
  });

  factory PublicCampaignNotification.fromFcm(Map<String, dynamic> data) {
    return PublicCampaignNotification(
      id: data['notificationId']?.toString() ?? data['id']?.toString() ?? '',
      type: data['type']?.toString() ?? 'campaign',
      title: data['title']?.toString() ?? 'Campaign',
      body: data['body']?.toString() ?? data['message']?.toString() ?? '',
      campaignSlug: data['campaignSlug']?.toString(),
      campaignId: data['campaignId'] == null ? null : campaignJsonInt(data['campaignId']),
      bookingRef: data['bookingRef']?.toString(),
      actionUrl: data['actionUrl']?.toString(),
    );
  }
}

class UpcomingCampaignMeta {
  final int id;
  final String slug;
  final int? remainingCapacity;
  final String? nextSlotDate;
  final int availableSlots;

  const UpcomingCampaignMeta({
    required this.id,
    required this.slug,
    this.remainingCapacity,
    this.nextSlotDate,
    this.availableSlots = 0,
  });

  factory UpcomingCampaignMeta.fromJson(Map<String, dynamic> json) {
    return UpcomingCampaignMeta(
      id: campaignJsonInt(json['id']),
      slug: json['slug']?.toString() ?? '',
      remainingCapacity: json['remainingCapacity'] == null
          ? null
          : campaignJsonInt(json['remainingCapacity']),
      nextSlotDate: json['nextSlotDate']?.toString(),
      availableSlots: campaignJsonInt(json['availableSlots']),
    );
  }
}

class CheckoutInitResult {
  final String checkoutId;
  final num amount;
  final String currency;
  final bool requiresPayment;
  final String? paymentUrl;
  final DateTime expiresAt;
  final String? bookingRef;
  final String? verificationCode;

  const CheckoutInitResult({
    required this.checkoutId,
    required this.amount,
    required this.currency,
    required this.requiresPayment,
    this.paymentUrl,
    required this.expiresAt,
    this.bookingRef,
    this.verificationCode,
  });

  factory CheckoutInitResult.fromJson(Map<String, dynamic> json) {
    return CheckoutInitResult(
      checkoutId: json['checkoutId']?.toString() ?? '',
      amount: json['amount'] is num ? json['amount'] as num : 0,
      currency: json['currency']?.toString() ?? 'BDT',
      requiresPayment: json['requiresPayment'] == true,
      paymentUrl: json['paymentUrl']?.toString(),
      expiresAt: campaignJsonDate(json['expiresAt']) ?? DateTime.now().add(const Duration(hours: 1)),
      bookingRef: json['bookingRef']?.toString(),
      verificationCode: json['verificationCode']?.toString(),
    );
  }
}

class CheckoutStatusResult {
  final String checkoutId;
  final String status;
  final num amount;
  final String? bookingRef;
  final String? verificationCode;

  const CheckoutStatusResult({
    required this.checkoutId,
    required this.status,
    required this.amount,
    this.bookingRef,
    this.verificationCode,
  });

  bool get isPaid => status == 'PAID' || status == 'FULFILLED';
  bool get isFailed => status == 'FAILED' || status == 'EXPIRED';

  factory CheckoutStatusResult.fromJson(Map<String, dynamic> json) {
    return CheckoutStatusResult(
      checkoutId: json['checkoutId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      amount: json['amount'] is num ? json['amount'] as num : 0,
      bookingRef: json['bookingRef']?.toString(),
      verificationCode: json['verificationCode']?.toString(),
    );
  }
}
