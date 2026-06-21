import 'package:flutter/material.dart';
import 'package:bpa_app/core/theme/typography.dart';
import 'package:bpa_app/core/storage/local_storage.dart';

/// Phase 5: First-launch country selection. Persists choice and applies to API (X-Country-Code).
class CountryPickerScreen extends StatelessWidget {
  const CountryPickerScreen({super.key});

  static const List<Map<String, String>> _countries = [
    {'code': 'BD', 'name': 'Bangladesh'},
    {'code': 'IN', 'name': 'India'},
    {'code': 'US', 'name': 'United States'},
    {'code': 'AE', 'name': 'UAE'},
  ];

  Future<void> _onSelect(BuildContext context, String code) async {
    await LocalStorage.setCountryCode(code);
    if (!context.mounted) return;
    final token = await LocalStorage.getToken();
    if (token != null && token.trim().isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text(
                'Select your country',
                style: context.appText.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This will apply to payments, content and support for your region.',
                style: context.appText.bodyMedium!.copyWith(color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ..._countries.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onSelect(context, c['code']!),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              c['name']!,
                              style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Text(
                              c['code']!,
                              style: context.appText.bodyMedium!.copyWith(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
