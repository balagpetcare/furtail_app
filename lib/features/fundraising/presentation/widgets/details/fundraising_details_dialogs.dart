import 'package:flutter/material.dart';

Future<int?> askDonationAmount(BuildContext context, {int defaultAmount = 500}) async {
  final controller = TextEditingController(text: defaultAmount.toString());
  return showDialog<int>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Donation amount'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Enter amount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n == null || n <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Invalid amount')),
                );
                return;
              }
              Navigator.of(ctx).pop(n);
            },
            child: const Text('Continue'),
          ),
        ],
      );
    },
  );
}

Future<bool?> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String okText = 'OK',
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(okText),
        ),
      ],
    ),
  );
}
