class Country {
  final int id;
  final String iso2;
  final String name;
  final String? iso3;
  final String? phoneCode;
  final String? currencyCode;
  final String? currencySymbol;
  final String? flagEmoji;
  final String? flagAssetUrl;
  final bool isSupported;
  final bool isDefault;
  final bool paymentEnabled;
  final bool contentEnabled;
  final bool supportEnabled;

  const Country({
    required this.id,
    required this.iso2,
    required this.name,
    this.iso3,
    this.phoneCode,
    this.currencyCode,
    this.currencySymbol,
    this.flagEmoji,
    this.flagAssetUrl,
    this.isSupported = false,
    this.isDefault = false,
    this.paymentEnabled = false,
    this.contentEnabled = true,
    this.supportEnabled = true,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: (json['id'] as num).toInt(),
      iso2: (json['iso2'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      iso3: json['iso3']?.toString(),
      phoneCode: json['phoneCode']?.toString(),
      currencyCode: json['currencyCode']?.toString(),
      currencySymbol: json['currencySymbol']?.toString(),
      flagEmoji: json['flagEmoji']?.toString(),
      flagAssetUrl: json['flagAssetUrl']?.toString(),
      isSupported: json['isSupported'] == true,
      isDefault: json['isDefault'] == true,
      paymentEnabled: json['paymentEnabled'] == true,
      contentEnabled: json['contentEnabled'] == true,
      supportEnabled: json['supportEnabled'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'iso2': iso2,
        'name': name,
        'iso3': iso3,
        'phoneCode': phoneCode,
        'currencyCode': currencyCode,
        'currencySymbol': currencySymbol,
        'flagEmoji': flagEmoji,
        'flagAssetUrl': flagAssetUrl,
        'isSupported': isSupported,
        'isDefault': isDefault,
        'paymentEnabled': paymentEnabled,
        'contentEnabled': contentEnabled,
        'supportEnabled': supportEnabled,
      };
}
