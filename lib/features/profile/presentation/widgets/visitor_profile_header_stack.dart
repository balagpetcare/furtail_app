import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';

import '../../data/models/visitor_profile_model.dart';

/// Visitor profile header — mirrors owner header quality but with no camera/edit controls.
class VisitorProfileHeaderStack extends StatelessWidget {
  final VisitorProfileModel profile;
  final String bioText;
  final List<String> followerPreviewUrls;
  final int followersCount;
  final int followingCount;

  const VisitorProfileHeaderStack({
    super.key,
    required this.profile,
    required this.bioText,
    required this.followerPreviewUrls,
    required this.followersCount,
    required this.followingCount,
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

    return Container(
      color: Colors.white,
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
                      ),
                ),
                if (username.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    style: TextStyle(
                      color: context.colorScheme.primary.withOpacity(0.85),
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
                style: const TextStyle(color: Colors.black87, height: 1.4, fontSize: 13.5),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'No bio added yet.',
                style: TextStyle(color: Colors.black38, fontSize: 13, fontStyle: FontStyle.italic),
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
        errorBuilder: (_, __, ___) => const _DefaultCover(),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover, width: double.infinity, height: double.infinity,
      placeholder: (_, __) => const _DefaultCover(),
      errorWidget: (_, __, ___) => const _DefaultCover(),
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
            child: Icon(Icons.pets, size: 56, color: Colors.white.withOpacity(0.20)),
          ),
        ),
        Positioned(
          left: 50, top: 55,
          child: Transform.rotate(
            angle: -0.5,
            child: Icon(Icons.pets, size: 34, color: Colors.white.withOpacity(0.12)),
          ),
        ),
        Positioned(
          right: 80, bottom: 16,
          child: Icon(Icons.favorite_rounded, size: 26, color: Colors.white.withOpacity(0.18)),
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
          colors: [Colors.transparent, Colors.black.withOpacity(0.22)],
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
            color: Colors.black.withOpacity(0.15),
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
        errorBuilder: (_, __, ___) => _defaultAvatar,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => _defaultAvatar,
      errorWidget: (_, __, ___) => _defaultAvatar,
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
