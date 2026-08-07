import 'package:furtail_app/services/api_client.dart';

class PetApiEnvelope {
  static List<Map<String, dynamic>> collectionItems(
    dynamic body, {
    required String url,
  }) {
    try {
      final envelope = _object(body);
      final data = envelope.containsKey('data') ? envelope['data'] : envelope;
      if (data == null) return const [];
      if (data is List) return data.map(_object).toList(growable: false);
      final dataMap = _object(data);
      final items = dataMap['items'];
      if (items == null) return const [];
      if (items is! List) {
        throw const FormatException('data.items must be a list');
      }
      return items.map(_object).toList(growable: false);
    } catch (error) {
      throw malformed(url, details: error.toString());
    }
  }

  static Map<String, dynamic> resourceItem(
    dynamic body, {
    required String url,
  }) {
    try {
      final envelope = _object(body);
      final data = envelope.containsKey('data') ? envelope['data'] : envelope;
      final dataMap = _object(data);
      final item = dataMap.containsKey('item') ? dataMap['item'] : dataMap;
      return _object(item);
    } catch (error) {
      throw malformed(url, details: error.toString());
    }
  }

  static List<Map<String, dynamic>> optionalList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map(_object).toList(growable: false);
  }

  static ApiClientException malformed(String url, {Object? details}) {
    return ApiClientException(
      message:
          'Received an unexpected pet response from the server. Please try again.',
      code: 'MALFORMED_RESPONSE',
      url: url,
      responseData: details,
    );
  }

  static Map<String, dynamic> _object(dynamic raw) {
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const FormatException('Expected JSON object');
  }
}
