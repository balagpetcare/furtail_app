import 'package:flutter/material.dart';

class MediaEngagementSummary {
  final int mediaId;
  final int pawCount;
  final int commentCount;
  final int shareCount;
  final bool isPawed;

  const MediaEngagementSummary({
    required this.mediaId,
    required this.pawCount,
    required this.commentCount,
    required this.shareCount,
    required this.isPawed,
  });

  MediaEngagementSummary copyWith({
    int? pawCount,
    int? commentCount,
    int? shareCount,
    bool? isPawed,
  }) {
    return MediaEngagementSummary(
      mediaId: mediaId,
      pawCount: pawCount ?? this.pawCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      isPawed: isPawed ?? this.isPawed,
    );
  }
}

class MediaEngagementActions extends StatelessWidget {
  final MediaEngagementSummary summary;
  final VoidCallback onPawToggle;
  final VoidCallback onCommentPressed;
  final VoidCallback onSharePressed;

  const MediaEngagementActions({
    super.key,
    required this.summary,
    required this.onPawToggle,
    required this.onCommentPressed,
    required this.onSharePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Counts row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '${summary.pawCount} Paws · ${summary.commentCount} comments · ${summary.shareCount} shares',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const Divider(
            color: Colors.white10,
            height: 1,
            thickness: 0.5,
          ),
          // Actions row
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: summary.isPawed ? Icons.pets : Icons.pets_outlined,
                  label: 'Paw',
                  color: summary.isPawed ? primaryColor : Colors.white70,
                  onTap: onPawToggle,
                ),
              ),
              Expanded(
                child: _ActionButton(
                  icon: Icons.comment_outlined,
                  label: 'Comment',
                  color: Colors.white70,
                  onTap: onCommentPressed,
                ),
              ),
              Expanded(
                child: _ActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  color: Colors.white70,
                  onTap: onSharePressed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
