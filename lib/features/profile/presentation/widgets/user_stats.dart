import 'dart:ui';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter/material.dart';

class UserStats extends StatelessWidget {
  final int followers;
  final int? rank;
  final int pawPoints;

  const UserStats({
    super.key,
    required this.followers,
    required this.rank,
    required this.pawPoints,
  });

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value, IconData icon) {
      return Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Icon(icon, color: const Color(0xFFFFD700)),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: context.appText.titleMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: context.appText.labelMedium!.copyWith(color: Colors.white.withValues(alpha: 0.70), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final rankText = (rank == null) ? "--" : "#$rank";
    final followersText = followers >= 1000
        ? "${(followers / 1000).toStringAsFixed(1)}k"
        : "$followers";

    return Row(
      children: [
        stat("Followers", followersText, Icons.group),
        const SizedBox(width: 12),
        stat("Rank", rankText, Icons.emoji_events),
        const SizedBox(width: 12),
        stat("Like Points", "$pawPoints", Icons.favorite),
      ],
    );
  }
}
