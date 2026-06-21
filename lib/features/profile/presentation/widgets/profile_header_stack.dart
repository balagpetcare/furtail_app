import 'dart:io';

import 'package:bpa_app/core/theme/typography.dart';
import 'package:flutter/material.dart';

import '../../data/models/user_profile_model.dart';

/// Header with cover photo + overlapped avatar.
/// White background, Stack layout, camera icons for media updates.
class ProfileHeaderStack extends StatelessWidget {
  final UserProfileModel profile;
  final String batchText;
  final String bioText;
  final VoidCallback onTapCoverCamera;
  final VoidCallback onTapAvatarCamera;
  final List<String> followerPreviewUrls;
  final int followersCount;
  final int followingCount;

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
  });

  @override
  Widget build(BuildContext context) {
    // Requirement: cover is wide (width long) and height short.
    const coverH = 160.0;
    const avatarSize = 112.0; // square

    final name = profile.name;
    final username = (profile.username ?? '').trim();
    final cover = (profile.coverUrl ?? '').trim();
    final avatar = (profile.photoUrl ?? '').trim();

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: coverH,
                width: double.infinity,
                child: _coverWidget(cover),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: _cameraButton(onTap: onTapCoverCamera),
              ),
              Positioned(
                left: 16,
                bottom: -(avatarSize / 2),
                child: Stack(
                  children: [
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: const Color(0xFFEFEFEF),
                          child: (avatar.isEmpty)
                              ? const Center(
                                  child: Icon(
                                    Icons.person,
                                    size: 42,
                                    color: Colors.black38,
                                  ),
                                )
                              : Image(
                                  image: _imageProvider(avatar)!,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: _cameraButton(
                        onTap: onTapAvatarCamera,
                        small: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: (avatarSize / 2) + 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: context.appText.titleLarge!.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (username.isNotEmpty) ...[
                  Text('@$username', style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 4),
                ],
                Text(batchText, style: const TextStyle(color: Colors.black87)),
                const SizedBox(height: 12),

                _bioCard(bioText),
                const SizedBox(height: 12),

                Row(
                  children: [
                    ..._followersAvatars(followerPreviewUrls),
                    const SizedBox(width: 10),
                    Text(
                      '$followersCount Followers · $followingCount Following',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverWidget(String url) {
    final provider = _imageProvider(url);
    if (provider == null) {
      return Container(
        color: const Color(0xFFEFEFEF),
        child: const Center(
          child: Text('Cover Photo', style: TextStyle(color: Colors.black54)),
        ),
      );
    }
    return Image(image: provider, fit: BoxFit.cover);
  }

  List<Widget> _followersAvatars(List<String> urls) {
    final take = urls.take(5).toList();
    return List.generate(take.length, (i) {
      final u = take[i];
      return Align(
        widthFactor: 0.6,
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white,
          child: CircleAvatar(
            radius: 15,
            backgroundColor: const Color(0xFFEFEFEF),
            backgroundImage: _imageProvider(u),
          ),
        ),
      );
    });
  }

  Widget _bioCard(String bioText) {
    // 120-160 word requirement will be enforced in edit form later.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE6E6E6)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bio', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            bioText,
            style: const TextStyle(height: 1.35, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  static ImageProvider<Object>? _imageProvider(String url) {
    if (url.trim().isEmpty) return null;
    if (url.startsWith('file://')) {
      return FileImage(File(url.replaceFirst('file://', '')));
    }
    return NetworkImage(url);
  }

  Widget _cameraButton({required VoidCallback onTap, bool small = false}) {
    // ✅ Use Material + GestureDetector to avoid "tap does nothing" issues on some layouts
    // (InkWell needs a Material ancestor for reliable hit testing + splash).
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(small ? 6 : 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.camera_alt, color: Colors.white, size: small ? 16 : 18),
        ),
      ),
    );
  }
}
