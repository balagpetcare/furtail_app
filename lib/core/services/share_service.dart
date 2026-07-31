import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Centralized share helper. Uses a deterministic canonical public URL and
/// app deep link, with no backend lookup or short-link dependency.
///
/// Supported types: post, fundraising, user, pet
class ShareService {
  static Future<void> share(
    BuildContext context, {
    required String type,
    required int id,
  }) async {
    await Share.share(canonicalShareMessage(type: type, id: id));
  }

  static String canonicalShareUrl({required String type, required int id}) {
    final t = type.toLowerCase();
    return 'https://furtail.app/$t/$id';
  }

  static String canonicalShareMessage({required String type, required int id}) {
    final t = type.toLowerCase();
    return 'Check this on Furtail\n${canonicalShareUrl(type: t, id: id)}\nfurtail://$t/$id';
  }
}
