import 'dart:convert';
import 'package:bpa_app/core/crash_reporting/crash_reporting_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }

  Future<Map<String, String>> _headers({required bool auth}) async {
    final headers = <String, String>{"Content-Type": "application/json"};
    if (auth) {
      final t = await _token();
      if (t == null || t.isEmpty) {
        throw Exception("Token not found. Please login again.");
      }
      headers["Authorization"] = "Bearer $t";
    }
    // Phase 5: X-Country-Code for API policy/context
    final prefs = await SharedPreferences.getInstance();
    final country = prefs.getString("bpa_country_code");
    if (country != null && country.trim().isNotEmpty) {
      headers["X-Country-Code"] = country.trim().toUpperCase();
    }
    final state = prefs.getString("bpa_state_code");
    if (state != null && state.trim().isNotEmpty) {
      headers["X-State-Code"] = state.trim().toUpperCase();
    }
    return headers;
  }

  dynamic _safeDecode(String body) {
    if (body.trim().isEmpty) return {};
    try {
      return jsonDecode(body);
    } catch (_) {
      return {"raw": body};
    }
  }

  dynamic _handle(
    http.Response res, {
    required String method,
    required String url,
  }) {
    final decoded = _safeDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }

    final msg = (decoded is Map && decoded["message"] != null)
        ? decoded["message"].toString()
        : "API Error";

    final error = Exception("$msg (${res.statusCode})");
    CrashReportingService.instance.recordNetworkError(
      method: method,
      url: url,
      error: error,
      statusCode: res.statusCode,
    );
    throw error;
  }

  Future<T> _runHttp<T>(
    String method,
    String url,
    Future<T> Function() request,
  ) async {
    try {
      return await request();
    } catch (e, st) {
      final msg = e.toString();
      if (!msg.contains('API Error') && !msg.contains('Upload Error')) {
        await CrashReportingService.instance.recordNetworkError(
          method: method,
          url: url,
          error: e,
          stackTrace: st,
        );
      }
      rethrow;
    }
  }

  Future<dynamic> get(String url, {bool auth = true}) async {
    return _runHttp('GET', url, () async {
      final res = await http.get(
        Uri.parse(url),
        headers: await _headers(auth: auth),
      );
      return _handle(res, method: 'GET', url: url);
    });
  }

  Future<dynamic> post(
    String url,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    return _runHttp('POST', url, () async {
      final res = await http.post(
        Uri.parse(url),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      );
      return _handle(res, method: 'POST', url: url);
    });
  }

  Future<dynamic> patch(
    String url,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    return _runHttp('PATCH', url, () async {
      final res = await http.patch(
        Uri.parse(url),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      );
      return _handle(res, method: 'PATCH', url: url);
    });
  }

  Future<dynamic> delete(String url, {bool auth = true}) async {
    return _runHttp('DELETE', url, () async {
      final res = await http.delete(
        Uri.parse(url),
        headers: await _headers(auth: auth),
      );
      return _handle(res, method: 'DELETE', url: url);
    });
  }

  Future<dynamic> multipartPost({
    required String url,
    required String fieldName,
    required String filePath,
    bool auth = true,
    Map<String, String>? fields,
  }) async {
    return _runHttp('POST', url, () async {
      final req = http.MultipartRequest('POST', Uri.parse(url));

      if (auth) {
        final t = await _token();
        if (t == null || t.isEmpty) {
          throw Exception('Token not found. Please login again.');
        }
        req.headers['Authorization'] = 'Bearer $t';
      }

      if (fields != null) req.fields.addAll(fields);
      req.files.add(await http.MultipartFile.fromPath(fieldName, filePath));

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        return _safeDecode(body);
      }

      final decoded = _safeDecode(body);
      final msg = (decoded is Map && decoded['message'] != null)
          ? decoded['message'].toString()
          : 'Upload Error';

      final error = Exception('$msg (${streamed.statusCode})');
      await CrashReportingService.instance.recordNetworkError(
        method: 'POST',
        url: url,
        error: error,
        statusCode: streamed.statusCode,
      );
      throw error;
    });
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});
