import 'dart:io';

import 'package:dio/dio.dart' show CancelToken, DioException;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/user_profile_model.dart';
import '../../../data/profile_service.dart';
import '../../widgets/settings_scaffold.dart';

enum _MediaSlot { avatar, cover }

/// Independent avatar/cover preview, upload, remove, progress, retry.
/// A media failure never discards the other slot's state — each slot has
/// its own upload lifecycle and error handling.
class ProfileAppearanceScreen extends StatefulWidget {
  const ProfileAppearanceScreen({super.key, required this.initial, this.profileService});
  final UserProfileModel initial;
  final ProfileService? profileService;

  @override
  State<ProfileAppearanceScreen> createState() => _ProfileAppearanceScreenState();
}

class _ProfileAppearanceScreenState extends State<ProfileAppearanceScreen> {
  late final ProfileService _svc = widget.profileService ?? ProfileService();

  String? _avatarUrl;
  String? _coverUrl;
  File? _avatarPending;
  File? _coverPending;
  double? _avatarProgress;
  double? _coverProgress;
  String? _avatarError;
  String? _coverError;
  CancelToken? _avatarCancel;
  CancelToken? _coverCancel;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.initial.photoUrl;
    _coverUrl = widget.initial.coverUrl;
  }

  bool get _avatarBusy => _avatarProgress != null;
  bool get _coverBusy => _coverProgress != null;

  Future<void> _pickAndUpload(_MediaSlot slot) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final file = File(picked.path);
    if (slot == _MediaSlot.avatar) {
      setState(() {
        _avatarPending = file;
        _avatarError = null;
      });
    } else {
      setState(() {
        _coverPending = file;
        _coverError = null;
      });
    }
    await _upload(slot, file);
  }

  Future<void> _upload(_MediaSlot slot, File file) async {
    final cancelToken = CancelToken();
    setState(() {
      if (slot == _MediaSlot.avatar) {
        _avatarProgress = 0;
        _avatarCancel = cancelToken;
      } else {
        _coverProgress = 0;
        _coverCancel = cancelToken;
      }
    });

    try {
      final mediaId = await _svc.uploadMediaWithProgress(
        file: file,
        cancelToken: cancelToken,
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() {
            final p = sent / total;
            if (slot == _MediaSlot.avatar) {
              _avatarProgress = p;
            } else {
              _coverProgress = p;
            }
          });
        },
      );

      final updated = await _svc.updateProfile({
        slot == _MediaSlot.avatar ? 'avatarMediaId' : 'coverMediaId': mediaId,
      });

      if (!mounted) return;
      setState(() {
        if (slot == _MediaSlot.avatar) {
          _avatarUrl = updated.photoUrl;
          _avatarPending = null;
          _avatarProgress = null;
          _avatarCancel = null;
        } else {
          _coverUrl = updated.coverUrl;
          _coverPending = null;
          _coverProgress = null;
          _coverCancel = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is DioException && CancelToken.isCancel(e)
          ? 'Upload cancelled.'
          : e.toString().replaceAll('Exception: ', '');
      // Keep the pending local file selected so the user can retry without
      // re-picking, and never touch the other slot's state.
      setState(() {
        if (slot == _MediaSlot.avatar) {
          _avatarProgress = null;
          _avatarCancel = null;
          _avatarError = message;
        } else {
          _coverProgress = null;
          _coverCancel = null;
          _coverError = message;
        }
      });
    }
  }

  void _retry(_MediaSlot slot) {
    final file = slot == _MediaSlot.avatar ? _avatarPending : _coverPending;
    if (file == null) return;
    _upload(slot, file);
  }

  void _cancel(_MediaSlot slot) {
    (slot == _MediaSlot.avatar ? _avatarCancel : _coverCancel)?.cancel();
  }

  Future<void> _remove(_MediaSlot slot) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${slot == _MediaSlot.avatar ? 'avatar' : 'cover photo'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final updated = await _svc.updateProfile({
        slot == _MediaSlot.avatar ? 'avatarMediaId' : 'coverMediaId': null,
      });
      if (!mounted) return;
      setState(() {
        if (slot == _MediaSlot.avatar) {
          _avatarUrl = updated.photoUrl;
        } else {
          _coverUrl = updated.coverUrl;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Profile Appearance',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MediaSlotCard(
            title: 'Cover photo',
            circular: false,
            imageUrl: _coverUrl,
            pendingFile: _coverPending,
            progress: _coverProgress,
            error: _coverError,
            onPick: () => _pickAndUpload(_MediaSlot.cover),
            onRetry: _coverError != null ? () => _retry(_MediaSlot.cover) : null,
            onCancel: _coverBusy ? () => _cancel(_MediaSlot.cover) : null,
            onRemove: (_coverUrl != null && !_coverBusy) ? () => _remove(_MediaSlot.cover) : null,
          ),
          const SizedBox(height: 24),
          _MediaSlotCard(
            title: 'Avatar',
            circular: true,
            imageUrl: _avatarUrl,
            pendingFile: _avatarPending,
            progress: _avatarProgress,
            error: _avatarError,
            onPick: () => _pickAndUpload(_MediaSlot.avatar),
            onRetry: _avatarError != null ? () => _retry(_MediaSlot.avatar) : null,
            onCancel: _avatarBusy ? () => _cancel(_MediaSlot.avatar) : null,
            onRemove: (_avatarUrl != null && !_avatarBusy)
                ? () => _remove(_MediaSlot.avatar)
                : null,
          ),
        ],
      ),
    );
  }
}

class _MediaSlotCard extends StatelessWidget {
  const _MediaSlotCard({
    required this.title,
    required this.circular,
    required this.imageUrl,
    required this.pendingFile,
    required this.progress,
    required this.error,
    required this.onPick,
    this.onRetry,
    this.onCancel,
    this.onRemove,
  });

  final String title;
  final bool circular;
  final String? imageUrl;
  final File? pendingFile;
  final double? progress;
  final String? error;
  final VoidCallback onPick;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final height = circular ? 120.0 : 140.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(circular ? height / 2 : 12),
          child: SizedBox(
            height: height,
            width: circular ? height : double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: colors.surfaceContainerHighest),
                if (pendingFile != null)
                  Image.file(pendingFile!, fit: BoxFit.cover)
                else if (imageUrl != null)
                  Image.network(imageUrl!, fit: BoxFit.cover)
                else
                  Center(child: Icon(Icons.image_outlined, color: colors.onSurfaceVariant)),
                if (progress != null)
                  Container(
                    color: Colors.black45,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            value: progress! > 0 ? progress : null,
                            color: Colors.white,
                          ),
                          if (onCancel != null) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: onCancel,
                              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: TextStyle(color: colors.error, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(onPressed: onPick, child: const Text('Choose photo')),
            if (onRetry != null) OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            if (onRemove != null)
              TextButton(
                onPressed: onRemove,
                style: TextButton.styleFrom(foregroundColor: colors.error),
                child: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }
}
