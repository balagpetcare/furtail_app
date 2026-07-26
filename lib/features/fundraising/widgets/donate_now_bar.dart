import 'package:flutter/material.dart';

// import 'package:furtail_app/core/constants/app_colors.dart';

class DonateNowBar extends StatelessWidget {
  final VoidCallback? onDonate;
  final bool isLoading;
  final String label;
  final String? disabledMessage;

  const DonateNowBar({
    super.key,
    required this.onDonate,
    this.isLoading = false,
    this.label = 'Donate Now',
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onDonate,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.volunteer_activism_outlined),
              label: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF6C945),
                foregroundColor: const Color(0xFF1E1400),
                disabledBackgroundColor: const Color(0xFFE7D8A5),
                disabledForegroundColor: const Color(0xFF6B5B2A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
