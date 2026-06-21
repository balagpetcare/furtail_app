import 'package:flutter/material.dart';
import 'package:bpa_app/core/theme/typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bpa_app/core/localization/locale_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeAsync = ref.watch(localeControllerProvider);
    final currentCode = localeAsync.maybeWhen(
      data: (l) => l.languageCode,
      orElse: () => 'en',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Language',
            style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE6E6E6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.language),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'App language',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentCode,
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await ref
                          .read(localeControllerProvider.notifier)
                          .setLocale(v);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Language updated ✅')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Note',
            style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'You can change language anytime from here. The app will not ask language on startup anymore.',
            style: TextStyle(height: 1.35, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
