class CountryReferenceModel {
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

  const CountryReferenceModel({
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

  factory CountryReferenceModel.fromJson(Map<String, dynamic> json) {
    return CountryReferenceModel(
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

  bool get isBangladesh => iso2.trim().toUpperCase() == 'BD';
}
