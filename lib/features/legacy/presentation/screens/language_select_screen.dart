import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/l10n/app_localizations.dart';
import 'package:furtail_app/core/localization/locale_controller.dart';

class LanguageSelectScreen extends ConsumerWidget {
  final VoidCallback onContinue;
  const LanguageSelectScreen({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;

    Widget button({required String label, required String code}) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            await ref.read(localeControllerProvider.notifier).setLocale(code);
            onContinue();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              label,
              style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.selectLanguage)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Text(
              t.selectLanguage,
              style: context.appText.titleLarge!.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            button(label: t.english, code: 'en'),
            const SizedBox(height: 10),
            button(label: t.bangla, code: 'bn'),
            const Spacer(),
            Text(
              'আপনি পরে Settings থেকে ভাষা পরিবর্তন করতে পারবেন।',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
