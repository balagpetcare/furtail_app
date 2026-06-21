import 'package:flutter/material.dart';
import 'permission_service.dart';

Future<bool> showPermissionDialog({
  required BuildContext context,
  required String title,
  required String message,
  required PermissionService service,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Not now"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Open Settings"),
        ),
      ],
    ),
  );

  if (res == true) {
    await service.openSettings();
  }
  return res ?? false;
}
