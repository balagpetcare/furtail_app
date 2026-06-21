import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/profile_service.dart';
import '../../data/models/user_profile_model.dart';

/// Edit own profile (English UI labels)
class EditProfileScreen extends StatefulWidget {
  final UserProfileModel initial;
  const EditProfileScreen({super.key, required this.initial});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
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
    _bio = TextEditingController();
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

      // Keep Home header + drawer avatar in sync
      final sp = await SharedPreferences.getInstance();
      await sp.setString('userName', updated.name);
      await sp.setString('userEmail', updated.email ?? "");
      if ((updated.photoUrl ?? "").trim().isNotEmpty) {
        await sp.setString('avatarUrl', updated.photoUrl!.trim());
      }

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
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                      child: (_avatarFile == null && (widget.initial.photoUrl ?? '').trim().isEmpty)
                          ? const Icon(Icons.person, size: 34)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickCover,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(_coverFile == null ? 'Change cover photo' : 'Cover selected'),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _displayName,
                validator: _required,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Username (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bio,
                maxLines: 3,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
                  if (words < 120 || words > 160) {
                    return 'Bio must be 120–160 words';
                  }
                  return null;
                },
                decoration: const InputDecoration(labelText: 'Bio (120–160 words)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone (optional)'),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
