import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../network/api_endpoints.dart';

/// Centralized share helper. Uses backend-generated share message.
///
/// Supported types: post, fundraising, user, pet
class ShareService {
  static Future<void> share(
    BuildContext context, {
    required String type,
    required int id,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await http.get(Uri.parse(ApiEndpoints.shareLink(type: type, id: id)));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final msg = decoded['data']?['message'] ?? decoded['data']?['data']?['message'];
        final message = (msg is String && msg.trim().isNotEmpty)
            ? msg.trim()
            : _fallbackMessage(type: type, id: id);
        await Share.share(message);
        return;
      }
      // fallback
      await Share.share(_fallbackMessage(type: type, id: id));
    } catch (_) {
      await Share.share(_fallbackMessage(type: type, id: id));
      messenger.showSnackBar(
        const SnackBar(content: Text('Shared with fallback link.')),
      );
    }
  }

  static String _fallbackMessage({required String type, required int id}) {
    final t = type.toLowerCase();
    return 'Check this on Furtail\nhttps://furtail.app/$t/$id\nfurtail://$t/$id';
  }
}
