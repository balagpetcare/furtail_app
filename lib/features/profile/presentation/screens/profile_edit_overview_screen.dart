import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/typography.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/profile_service.dart';
import '../widgets/profile_media_upload_screen.dart';

/// Profile edit overview...
class ProfileEditOverviewScreen extends StatefulWidget {
  final UserProfileModel initial;
  const ProfileEditOverviewScreen({super.key, required this.initial});

  @override
  State<ProfileEditOverviewScreen> createState() => _ProfileEditOverviewScreenState();
}

class _ProfileEditOverviewScreenState extends State<ProfileEditOverviewScreen> {
  final _svc = ProfileService();
  late UserProfileModel _p;

  bool _savingBio = false;

  @override
  void initState() {
    super.initState();
    _p = widget.initial;
  }

  Future<void> _updateCover() async {
    final result = await Navigator.push<ProfileMediaUploadResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileMediaUploadScreen(
          title: 'Update Cover Photo',
          cropStyle: ProfileCropStyle.cover,
        ),
      ),
    );
    if (result == null) return;
    setState(() => _p = _p.copyWith(coverUrl: result.previewUrl));
    await _svc.updateProfile({"coverMediaId": result.mediaId});
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _updateAvatar() async {
    final result = await Navigator.push<ProfileMediaUploadResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileMediaUploadScreen(
          title: 'Update Profile Photo',
          cropStyle: ProfileCropStyle.avatar,
        ),
      ),
    );
    if (result == null) return;
    setState(() => _p = _p.copyWith(photoUrl: result.previewUrl));
    await _svc.updateProfile({"avatarMediaId": result.mediaId});
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _editBio() async {
    final current = (_p.bio ?? '').trim();
    final c = TextEditingController(text: current);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit Bio', style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Write 120–160 words about yourself',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Word count: ${_wordCount(c.text)} (required: 120–160)',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final wc = _wordCount(c.text);
                    if (wc < 120 || wc > 160) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Bio must be 120–160 words.')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (ok != true) return;
    final text = c.text.trim();

    setState(() {
      _savingBio = true;
      _p = _p.copyWith(bio: text);
    });
    try {
      await _svc.updateProfile({"bio": text});
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _savingBio = false);
    }
  }

  static int _wordCount(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Photos', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _tile('Update Profile Photo', 'Square crop', _updateAvatar),
          _tile('Update Cover Photo', 'Wide crop', _updateCover),
          const SizedBox(height: 18),
          const Text('About', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _tile('Edit Bio', _savingBio ? 'Saving...' : '120–160 words', _editBio),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x11000000)),
            ),
            child: const Text(
              'Next: Add separate edit pages for Education, Place Live, Work, Religion, Birthdate, Marital Status, etc. (See About > See More).',
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
