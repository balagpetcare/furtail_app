import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bpa_app/core/network/api_config.dart';

/// Phase 5: Policy features (DONATION, ADS, PRODUCTS) for UI visibility.
class PolicyFeatures {
  final String countryCode;
  final bool donationEnabled;
  final bool fundraisingEnabled;
  final bool adsEnabled;
  final bool productsEnabled;

  const PolicyFeatures({
    required this.countryCode,
    this.donationEnabled = true,
    this.fundraisingEnabled = false,
    this.adsEnabled = false,
    this.productsEnabled = true,
  });
}

final policyFeaturesProvider = FutureProvider<PolicyFeatures>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('bpa_country_code') ?? 'BD';
    final url = '${ApiConfig.host}/api/v1/meta/features?countryCode=$code';
    final res = await http.get(
      Uri.parse(url),
      headers: {'X-Country-Code': code, 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return const PolicyFeatures(countryCode: 'BD');
    final decoded = jsonDecode(res.body);
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! Map) return PolicyFeatures(countryCode: code);
    final features = data['features'] is Map ? data['features'] as Map : {};
    return PolicyFeatures(
      countryCode: data['countryCode']?.toString() ?? code,
      donationEnabled: features['DONATION'] == true,
      fundraisingEnabled: features['FUNDRAISING'] == true,
      adsEnabled: features['ADS'] == true,
      productsEnabled: features['PRODUCTS'] != false,
    );
  } catch (_) {
    return const PolicyFeatures(countryCode: 'BD');
  }
});
