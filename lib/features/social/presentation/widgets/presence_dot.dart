import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/theme_extensions.dart';

import '../../data/models/presence_info.dart';
import 'shared_social_components.dart';

/// A small green "Active now" dot anchored to an avatar's bottom-right
/// corner, with a ring matching the surrounding surface so it reads as a
/// cutout rather than a sticker covering the photo. Reuses the app's
/// existing success/green design token (`context.bpaSuccess`) — never a
/// hardcoded color — and renders nothing at all when [isOnline] is false,
/// so an offline/unknown friend's avatar is untouched.
class PresenceDot extends StatelessWidget {
  const PresenceDot({super.key, required this.isOnline, this.diameter = 14});

  final bool isOnline;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    if (!isOnline) return const SizedBox.shrink();
    final ringColor = Theme.of(context).scaffoldBackgroundColor;
    return Semantics(
      label: 'Active now',
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.bpaSuccess,
          border: Border.all(color: ringColor, width: diameter * 0.15),
        ),
      ),
    );
  }
}

/// [SocialAvatar] with an optional [PresenceDot] overlaid at the bottom-right
/// — the shared building block Friends/Inbox/Chat all use so the dot's size
/// and positioning stay identical everywhere instead of each screen placing
/// it by hand.
class PresenceAvatar extends StatelessWidget {
  const PresenceAvatar({
    super.key,
    required this.url,
    required this.displayName,
    this.radius = 28,
    this.isOnline = false,
  });

  final String? url;
  final String displayName;
  final double radius;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final dotDiameter = radius * 0.5;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SocialAvatar(url: url, displayName: displayName, radius: radius),
        if (isOnline)
          Positioned(
            right: -dotDiameter * 0.08,
            bottom: -dotDiameter * 0.08,
            child: PresenceDot(isOnline: true, diameter: dotDiameter),
          ),
      ],
    );
  }
}

/// The "Active now" / "Active 5m ago" line, styled to match
/// [SocialNameAndContext]'s muted context row — returns nothing when
/// [presence] has no status to show (stranger/blocked/opted-out/never seen),
/// per the same silent-omission rule the backend enforces.
class PresenceStatusLabel extends StatelessWidget {
  const PresenceStatusLabel({super.key, required this.presence});

  final PresenceInfo presence;

  @override
  Widget build(BuildContext context) {
    final label = presence.statusLabel;
    if (label == null) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    final color = presence.isOnline
        ? context.bpaSuccess
        : context.mutedTextColor;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: presence.isOnline ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }
}
