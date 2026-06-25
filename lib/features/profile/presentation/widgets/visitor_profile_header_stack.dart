import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:furtail_app/core/media/furtail_cache_manager.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';

import '../../data/models/visitor_profile_model.dart';

/// Visitor profile header — mirrors owner header quality but with no camera/edit controls.
class VisitorProfileHeaderStack extends StatelessWidget {
  final VisitorProfileModel profile;
  final String bioText;
  final List<String> followerPreviewUrls;
  final int followersCount;
  final int followingCount;
  final bool showBackButton;
  final VoidCallback? onShare;
  final VoidCallback? onBack;
  final Widget? moreActionsButton;

  const VisitorProfileHeaderStack({
    super.key,
    required this.profile,
    required this.bioText,
    required this.followerPreviewUrls,
    required this.followersCount,
    required this.followingCount,
    this.showBackButton = false,
    this.onShare,
    this.onBack,
    this.moreActionsButton,
  });

  static const double _coverH = 200;
  static const double _avatarSize = 100;
  static const double _halfAvatar = _avatarSize / 2;

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName;
    final username = (profile.username ?? '').trim();
    final coverUrl = (profile.coverUrl ?? '').trim();
    final avatarUrl = (profile.avatarUrl ?? '').trim();

    final cs = context.colorScheme;

    return Container(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _coverH + _halfAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0, right: 0, top: 0, height: _coverH,
                  child: _VisitorCover(url: coverUrl),
                ),
                Positioned(
                  left: 0, right: 0,
                  top: _coverH - 64, height: 64,
                  child: const _BottomFade(),
                ),
                // Floating top navigation buttons (transparent with icons and shadow)
                if (showBackButton)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _FloatingActionButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: onBack ?? () => Navigator.maybePop(context),
                      tooltip: 'Back',
                    ),
                  ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onShare != null)
                        _FloatingActionButton(
                          icon: Icons.share_outlined,
                          onTap: onShare!,
                          tooltip: 'Share',
                        ),
                      if (moreActionsButton != null) ...[
                        const SizedBox(width: 8),
                        moreActionsButton!,
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  top: _coverH - _halfAvatar,
                  child: _VisitorAvatar(url: avatarUrl, name: name),
                ),
              ],
            ),
          ),

          // Name
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: cs.onSurface,
                      ),
                ),
                if (username.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    style: TextStyle(
                      color: cs.primary.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Bio
          if (bioText.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                bioText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurface, height: 1.4, fontSize: 13.5),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'No bio added yet.',
                style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
          ],

          // Follower preview avatars
          if (followerPreviewUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _FollowerPreviewRow(
                urls: followerPreviewUrls,
                totalCount: followersCount,
              ),
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── Private helpers ─────────────────────────────────────────────────────────

class _VisitorCover extends StatelessWidget {
  final String url;
  const _VisitorCover({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const _DefaultCover();
    if (url.startsWith('file://')) {
      return Image.file(
        File(url.replaceFirst('file://', '')),
        fit: BoxFit.cover, width: double.infinity, height: double.infinity,
        errorBuilder: (_, _, _) => const _DefaultCover(),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: FurtailImageCacheManager(),
      fit: BoxFit.cover, width: double.infinity, height: double.infinity,
      placeholder: (_, _) => const _DefaultCover(),
      errorWidget: (_, _, _) => const _DefaultCover(),
    );
  }
}

class _DefaultCover extends StatelessWidget {
  const _DefaultCover();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
          ),
        ),
        Positioned(
          right: 18, top: 18,
          child: Transform.rotate(
            angle: 0.3,
            child: Icon(Icons.pets, size: 56, color: Colors.white.withValues(alpha: 0.20)),
          ),
        ),
        Positioned(
          left: 50, top: 55,
          child: Transform.rotate(
            angle: -0.5,
            child: Icon(Icons.pets, size: 34, color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),
        Positioned(
          right: 80, bottom: 16,
          child: Icon(Icons.favorite_rounded, size: 26, color: Colors.white.withValues(alpha: 0.18)),
        ),
      ],
    );
  }
}

class _BottomFade extends StatelessWidget {
  const _BottomFade();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)],
        ),
      ),
    );
  }
}

class _VisitorAvatar extends StatelessWidget {
  final String url;
  final String name;
  const _VisitorAvatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: VisitorProfileHeaderStack._avatarSize,
      height: VisitorProfileHeaderStack._avatarSize,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: _AvatarContent(url: url, name: name),
      ),
    );
  }
}

class _AvatarContent extends StatelessWidget {
  final String url;
  final String name;
  const _AvatarContent({required this.url, required this.name});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _defaultAvatar;
    if (url.startsWith('file://')) {
      return Image.file(
        File(url.replaceFirst('file://', '')),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _defaultAvatar,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: FurtailImageCacheManager(),
      fit: BoxFit.cover,
      placeholder: (_, _) => _defaultAvatar,
      errorWidget: (_, _, _) => _defaultAvatar,
    );
  }

  Widget get _defaultAvatar => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
      ),
    ),
    child: Center(
      child: Text(
        _initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 34,
          letterSpacing: 1,
        ),
      ),
    ),
  );
}

class _FloatingActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _FloatingActionButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0x73000000),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _FollowerPreviewRow extends StatelessWidget {
  final List<String> urls;
  final int totalCount;

  const _FollowerPreviewRow({required this.urls, required this.totalCount});

  static const double _size = 26.0;
  static const double _overlap = 8.0;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final show = urls.take(5).toList();
    final stackWidth = _size + (_size - _overlap) * (show.length - 1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: stackWidth,
          height: _size,
          child: Stack(
            children: List.generate(show.length, (i) {
              return Positioned(
                left: i * (_size - _overlap),
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 1.5),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: show[i],
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => CircleAvatar(
                        radius: _size / 2,
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.person, size: 14, color: cs.onPrimaryContainer),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$totalCount ${totalCount == 1 ? 'follower' : 'followers'}',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
