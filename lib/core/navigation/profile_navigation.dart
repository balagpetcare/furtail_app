import 'package:flutter/material.dart';
import 'package:furtail_app/app/router/app_routes.dart';
import 'package:furtail_app/core/storage/local_storage.dart';

abstract final class ProfileNavigation {
  static Future<void> openUserProfile(BuildContext context, dynamic rawUserId) async {
    if (rawUserId == null) return;

    final int? targetUserId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId.toString().trim());

    if (targetUserId == null || targetUserId <= 0) return;

    final int? currentUserId = await LocalStorage.getUserId();

    if (!context.mounted) return;

    if (currentUserId != null && targetUserId == currentUserId) {
      Navigator.pushNamed(context, AppRoutes.profile);
    } else {
      Navigator.pushNamed(
        context,
        AppRoutes.visitorProfile,
        arguments: {'userId': targetUserId},
      );
    }
  }
}
