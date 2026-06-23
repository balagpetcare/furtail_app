import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';

import '../../data/models/user_profile_model.dart';

enum _CamSize { normal, small }

/// Owner profile header with cover + avatar + stats + action buttons.
///
/// FIX: The old implementation placed the avatar at bottom:-56 (outside
/// the Stack's layout bounds), causing hit-testing to fail silently.
/// Now the Stack is tall enough to contain the avatar area.
class ProfileHeaderStack extends StatelessWidget {
  final UserProfileModel profile;
  final String batchText;
  final String bioText;
  final VoidCallback onTapCoverCamera;
  final VoidCallback onTapAvatarCamera;
  final List<String> followerPreviewUrls;
  final int followersCount;
  final int followingCount;
  final VoidCallback? onEditProfile;
  final VoidCallback? onAddPet;
  final VoidCallback? onCreatePost;

  const ProfileHeaderStack({
    super.key,
    required this.profile,
    required this.batchText,
    required this.bioText,
    required this.onTapCoverCamera,
    required this.onTapAvatarCamera,
    required this.followerPreviewUrls,
    required this.followersCount,
    required this.followingCount,
    this.onEditProfile,
    this.onAddPet,
    this.onCreatePost,
  });

  static const double _coverH = 200;
  static const double _avatarSize = 100;
  static const double _halfAvatar = _avatarSize / 2;

  @override
  Widget build(BuildContext context) {
    final name = profile.name;
    final username = (profile.username ?? '').trim();
    final coverUrl = (profile.coverUrl ?? '').trim();
    final avatarUrl = (profile.photoUrl ?? '').trim();
    final tier = (profile.tier ?? '').trim();
    final petsCount = profile.pets.length;
    final cs = context.colorScheme;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stack height = coverH + halfAvatar so avatar is within bounds.
          // Previously avatar was at bottom:-56 → outside Stack → no touch events.
          SizedBox(
            height: _coverH + _halfAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover
                Positioned(
                  left: 0, right: 0, top: 0, height: _coverH,
                  child: _ProfileCover(url: coverUrl),
                ),
                // Bottom gradient on cover for depth
                Positioned(
                  left: 0, right: 0,
                  top: _coverH - 64, height: 64,
                  child: const _BottomFade(),
                ),
                // Cover camera button (within stack bounds)
                Positioned(
                  right: 12,
                  top: _coverH - 48,
                  child: _CamBtn(onTap: onTapCoverCamera),
                ),
                // Avatar container + its camera button
                Positioned(
                  left: 16,
                  top: _coverH - _halfAvatar,
                  child: _AvatarWithCam(
                    url: avatarUrl,
                    name: name,
                    onTapCamera: onTapAvatarCamera,
                  ),
                ),
              ],
            ),
          ),

          // Name + tier
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
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
                            color: cs.primary.withOpacity(0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (tier.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _TierBadge(label: tier),
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
          ],

          const SizedBox(height: 12),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatChip(value: followersCount, label: 'Followers'),
                const SizedBox(width: 8),
                _StatChip(value: followingCount, label: 'Following'),
                const SizedBox(width: 8),
                _StatChip(value: petsCount, label: 'Pets'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEditProfile,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Profile'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(color: cs.primary),
                      foregroundColor: cs.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _IconActionBtn(
                  icon: Icons.pets_rounded,
                  tooltip: 'Add Pet',
                  onTap: onAddPet,
                ),
                const SizedBox(width: 8),
                _IconActionBtn(
                  icon: Icons.add_circle_outline_rounded,
                  tooltip: 'Create Post',
                  onTap: onCreatePost,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── Private helpers ─────────────────────────────────────────────────────────

class _ProfileCover extends StatelessWidget {
  final String url;
  const _ProfileCover({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const _DefaultCover();

    if (url.startsWith('file://')) {
      return Image.file(
        File(url.replaceFirst('file://', '')),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const _DefaultCover(),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
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
              colors: [Color(0xFFF97316), Color(0xFFFBBF24)],
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
            child: Icon(Icons.pets, size: 34, color: Colors.white.withOpacity(0.13)),
          ),
        ),
        Positioned(
          right: 80, bottom: 16,
          child: Icon(Icons.favorite_rounded, size: 26, color: Colors.white.withOpacity(0.18)),
        ),
        Positioned(
          left: 18, bottom: 22,
          child: Transform.rotate(
            angle: 0.4,
            child: Icon(Icons.pets, size: 22, color: Colors.white.withOpacity(0.12)),
          ),
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

class _AvatarArea extends StatelessWidget {
  final String url;
  final String name;
  const _AvatarArea({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _DefaultAvatar(name: name);

    if (url.startsWith('file://')) {
      return Image.file(
        File(url.replaceFirst('file://', '')),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _DefaultAvatar(name: name),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => _DefaultAvatar(name: name),
      errorWidget: (_, __, ___) => _DefaultAvatar(name: name),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  final String name;
  const _DefaultAvatar({required this.name});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF97316), Color(0xFFEF4444)],
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
}

class _AvatarWithCam extends StatelessWidget {
  final String url;
  final String name;
  final VoidCallback onTapCamera;
  const _AvatarWithCam({required this.url, required this.name, required this.onTapCamera});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: ProfileHeaderStack._avatarSize,
          height: ProfileHeaderStack._avatarSize,
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
            child: _AvatarArea(url: url, name: name),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 2,
          child: _CamBtn(onTap: onTapCamera, size: _CamSize.small),
        ),
      ],
    );
  }
}

class _CamBtn extends StatelessWidget {
  final VoidCallback onTap;
  final _CamSize size;
  const _CamBtn({required this.onTap, this.size = _CamSize.normal});

  @override
  Widget build(BuildContext context) {
    final isSmall = size == _CamSize.small;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(isSmall ? 6 : 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.60),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
          ),
          child: Icon(Icons.camera_alt, color: Colors.white, size: isSmall ? 15 : 18),
        ),
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  final String label;
  const _TierBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFBBF24)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final int value;
  final String label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8EAED)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _compact(value),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _IconActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _IconActionBtn({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: Colors.black87),
        ),
      ),
    );
  }
}
