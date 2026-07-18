import 'package:flutter/material.dart';

class SocialActionRow extends StatelessWidget {
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final bool showSaveButton;
  final bool isSaved;
  final VoidCallback? onSave;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry buttonPadding;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? selectedColor;
  final Color? dividerColor;
  final bool showDivider;

  const SocialActionRow({
    super.key,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.showSaveButton = false,
    this.isSaved = false,
    this.onSave,
    this.padding = const EdgeInsets.all(0),
    this.buttonPadding = const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    this.backgroundColor,
    this.foregroundColor,
    this.selectedColor,
    this.dividerColor,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = foregroundColor ?? theme.colorScheme.onSurfaceVariant;
    final activeColor = selectedColor ?? theme.colorScheme.primary;
    final likeLabel = _likeLabel(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _SocialActionButton(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                label: '$likeLabel ($likeCount)',
                color: isLiked ? activeColor : baseColor,
                onTap: onLike,
              ),
            ),
            Expanded(
              child: _SocialActionButton(
                icon: Icons.comment_outlined,
                label: 'Comment ($commentCount)',
                color: baseColor,
                onTap: onComment,
              ),
            ),
            Expanded(
              child: _SocialActionButton(
                icon: Icons.share_outlined,
                label: 'Share ($shareCount)',
                color: baseColor,
                onTap: onShare,
              ),
            ),
            if (showSaveButton)
              Expanded(
                child: _SocialActionButton(
                  icon: isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: 'Save',
                  color: isSaved ? activeColor : baseColor,
                  onTap: onSave ?? () {},
                ),
              ),
          ],
        ),
        if (showDivider)
          Divider(
            color: dividerColor ?? theme.dividerColor,
            height: 1,
          ),
      ],
    );

    final row = backgroundColor == null
        ? content
        : ColoredBox(color: backgroundColor!, child: content);

    return Padding(
      padding: padding,
      child: row,
    );
  }

  static String _likeLabel(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'bn'
        ? 'লাইক'
        : 'Like';
  }
}

class _SocialActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SocialActionButton({
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
        borderRadius: BorderRadius.circular(10),
          child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
