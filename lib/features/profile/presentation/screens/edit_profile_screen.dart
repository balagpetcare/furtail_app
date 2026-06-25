import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:furtail_app/core/providers/current_user_provider.dart';
import '../../data/profile_service.dart';
import '../../data/models/user_profile_model.dart';

/// Edit own profile (English UI labels)
class EditProfileScreen extends ConsumerStatefulWidget {
  final UserProfileModel initial;
  const EditProfileScreen({super.key, required this.initial});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _svc = ProfileService();
  final _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayName;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final TextEditingController _email;
  late final TextEditingController _phone;

  File? _avatarFile;
  File? _coverFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _displayName = TextEditingController(text: widget.initial.name);
    _username = TextEditingController(text: widget.initial.username ?? "");
    _bio = TextEditingController(text: widget.initial.bio ?? "");
    _email = TextEditingController(text: widget.initial.email ?? "");
    _phone = TextEditingController(text: widget.initial.phone ?? "");
  }

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _bio.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    if (_avatarFile != null || _coverFile != null) return true;
    if (_displayName.text.trim() != widget.initial.name) return true;
    if (_username.text.trim() != (widget.initial.username ?? "")) return true;
    if (_bio.text.trim() != (widget.initial.bio ?? "")) return true;
    if (_email.text.trim() != (widget.initial.email ?? "")) return true;
    if (_phone.text.trim() != (widget.initial.phone ?? "")) return true;
    return false;
  }

  Future<void> _pickAvatar() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (x == null) return;
    final cropped = await _crop(x.path, square: true);
    if (cropped == null) return;
    setState(() => _avatarFile = File(cropped.path));
  }

  Future<void> _pickCover() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (x == null) return;
    final cropped = await _crop(x.path, square: false);
    if (cropped == null) return;
    setState(() => _coverFile = File(cropped.path));
  }

  Future<CroppedFile?> _crop(String path, {required bool square}) {
    return ImageCropper().cropImage(
      sourcePath: path,
      compressQuality: 92,
      aspectRatio: square ? const CropAspectRatio(ratioX: 1, ratioY: 1) : const CropAspectRatio(ratioX: 16, ratioY: 9),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          initAspectRatio: square ? CropAspectRatioPreset.square : CropAspectRatioPreset.ratio16x9,
          aspectRatioPresets: [
            if (square) CropAspectRatioPreset.square,
            if (!square) CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(title: 'Crop Photo', aspectRatioLockEnabled: true),
      ],
    );
  }

  String? _required(String? v) {
    if ((v ?? "").trim().isEmpty) return "This field is required";
    return null;
  }

  static Widget _secLabel(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey,
        letterSpacing: 0.9,
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    // Avoid "Null check operator used on a null value" if the Form isn't mounted yet.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      int? avatarMediaId;
      int? coverMediaId;

      if (_avatarFile != null) {
        final bytes = await _avatarFile!.readAsBytes();
        avatarMediaId = await _svc.uploadMedia(bytes: bytes, filename: _avatarFile!.path.split('/').last);
      }
      if (_coverFile != null) {
        final bytes = await _coverFile!.readAsBytes();
        coverMediaId = await _svc.uploadMedia(bytes: bytes, filename: _coverFile!.path.split('/').last);
      }

      final payload = <String, dynamic>{
        "displayName": _displayName.text.trim(),
        "username": _username.text.trim().isEmpty ? null : _username.text.trim(),
        "bio": _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        "email": _email.text.trim().isEmpty ? null : _email.text.trim(),
        "phone": _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        if (avatarMediaId != null) "avatarMediaId": avatarMediaId,
        if (coverMediaId != null) "coverMediaId": coverMediaId,
      };

      final updated = await _svc.updateProfile(payload);

      // Keep Home header + drawer avatar in sync (SharedPreferences + reactive provider).
      final sp = await SharedPreferences.getInstance();
      await sp.setString('userName', updated.name);
      await sp.setString('userEmail', updated.email ?? "");
      if ((updated.photoUrl ?? "").trim().isNotEmpty) {
        await sp.setString('avatarUrl', updated.photoUrl!.trim());
      }
      // Notify the reactive provider so UI rebuilds immediately.
      await ref.read(currentUserProvider.notifier).reloadFromPrefs();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully"), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? 'Failed to update profile' : msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: const _GreyBackButton(),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    'Save',
                    style: TextStyle(
                      color: _saving ? Colors.grey : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          )
        ],
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_saving) return;
          if (!_hasUnsavedChanges) {
            Navigator.pop(context);
            return;
          }
          final discard = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Discard Changes?'),
              content: const Text('Are you sure you want to discard your changes?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep Editing'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          if (discard == true && context.mounted) {
            Navigator.pop(context);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Photos ───────────────────────────────────────────────────
              _secLabel('Photos'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Stack(
                    children: [
                      InkWell(
                        onTap: _pickAvatar,
                        borderRadius: BorderRadius.circular(999),
                        child: CircleAvatar(
                          radius: 34,
                          backgroundImage: _avatarFile != null
                              ? FileImage(_avatarFile!)
                              : ((widget.initial.photoUrl ?? '').trim().isNotEmpty
                                  ? NetworkImage(widget.initial.photoUrl!)
                                  : null) as ImageProvider<Object>?,
                          child: (_avatarFile == null &&
                                  (widget.initial.photoUrl ?? '').trim().isEmpty)
                              ? const Icon(Icons.person, size: 34)
                              : null,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickCover,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                          _coverFile == null ? 'Change cover photo' : 'Cover selected ✓'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Profile Basics ────────────────────────────────────────────
              _secLabel('Profile Basics'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _displayName,
                validator: _required,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  helperText: 'Your full name or nickname',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'e.g. pawlover99',
                  helperText: 'Optional — letters, numbers, underscores',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bio,
                maxLines: 3,
                maxLength: 200,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length > 200) return 'Bio must be 200 characters or less';
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Tell people a little about yourself...',
                  helperText: 'Up to 200 characters',
                  counterText: '',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),

              const SizedBox(height: 24),

              // ── Contact ───────────────────────────────────────────────────
              _secLabel('Contact'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Optional',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: 'Optional',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),

              const SizedBox(height: 28),
              // Bottom save removed — AppBar "Save" is the primary action.
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

/// Standard back button for white-background screens:
/// light grey circular background + dark icon.
class _GreyBackButton extends StatelessWidget {
  const _GreyBackButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFFE8EAED),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1A1A2E)),
      ),
    );
  }
}
