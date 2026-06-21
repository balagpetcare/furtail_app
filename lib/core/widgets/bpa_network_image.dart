import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/spacing.dart';

/// Standard network image with loading and error states.
class BpaCachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const BpaCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();
    final radius = borderRadius ?? BorderRadius.zero;

    Widget child;
    if (url.isEmpty) {
      child = errorWidget ?? _defaultError(context);
    } else {
      child = CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => placeholder ?? _defaultPlaceholder(context),
        errorWidget: (_, __, ___) => errorWidget ?? _defaultError(context),
      );
    }

    if (width != null || height != null) {
      child = SizedBox(width: width, height: height, child: child);
    }
    return ClipRRect(borderRadius: radius, child: child);
  }

  static Widget _defaultPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  static Widget _defaultError(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 28,
      ),
    );
  }
}

/// Circular avatar with CachedNetworkImage, initials fallback, and optional badge.
class BpaNetworkAvatar extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? badge;

  const BpaNetworkAvatar({
    super.key,
    required this.imageUrl,
    required this.displayName,
    this.radius = 24,
    this.backgroundColor,
    this.foregroundColor,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? cs.primary.withValues(alpha: 0.12);
    final fg = foregroundColor ?? cs.primary;
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : '?';
    final url = (imageUrl ?? '').trim();

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: url.isEmpty
          ? Text(
              initial,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.85,
              ),
            )
          : ClipOval(
              child: BpaCachedImage(
                imageUrl: url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: CircleAvatar(
                  radius: radius,
                  backgroundColor: bg,
                  child: SizedBox(
                    width: radius,
                    height: radius,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  ),
                ),
                errorWidget: CircleAvatar(
                  radius: radius,
                  backgroundColor: bg,
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: radius * 0.85,
                    ),
                  ),
                ),
              ),
            ),
    );

    if (badge == null) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(right: -2, bottom: -2, child: badge!),
      ],
    );
  }
}

/// Gold membership badge for drawer / profile headers.
class BpaMembershipBadge extends StatelessWidget {
  final bool isMember;
  final String label;

  const BpaMembershipBadge({
    super.key,
    required this.isMember,
    this.label = 'BPA Member',
  });

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.accentGold;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isMember ? gold : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isMember ? gold.withValues(alpha: 0.6) : Colors.white38,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMember ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded,
            size: 14,
            color: isMember ? const Color(0xFF5B4300) : Colors.white,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              isMember ? label : 'Guest',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTypographyScale.caption,
                fontWeight: FontWeight.w700,
                color: isMember ? const Color(0xFF5B4300) : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact action chip for drawer header.
class BpaActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const BpaActionChip({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppTypographyScale.caption,
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
