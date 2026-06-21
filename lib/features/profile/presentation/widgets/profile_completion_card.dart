import 'package:flutter/material.dart';

class ProfileCompletionCard extends StatelessWidget {
  final int completionPercent;
  final String levelText;
  final String pointsText;
  final String tipText;

  const ProfileCompletionCard({
    super.key,
    required this.completionPercent,
    required this.levelText,
    required this.pointsText,
    required this.tipText,
  });

  @override
  Widget build(BuildContext context) {
    final v = (completionPercent / 100.0).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE6E6E6)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 18),
              const SizedBox(width: 8),
              const Text('Profile Completion', style: TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('$completionPercent%', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: v, minHeight: 10),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _pill(Icons.bolt, levelText),
              const SizedBox(width: 8),
              _pill(Icons.stars, pointsText),
            ],
          ),
          const SizedBox(height: 8),
          Text(tipText, style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x11000000)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
