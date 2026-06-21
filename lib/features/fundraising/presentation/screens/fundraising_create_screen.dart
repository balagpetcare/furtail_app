import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/fundraising_providers.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'fundraising_account_setup_screen.dart';
import 'package:furtail_app/features/location/presentation/widgets/location_selector_widget.dart';

/// Fundraising create form (Phase A)
/// - Entry points:
///   1) Donation list (FundraisingFeedScreen) app bar action
///   2) Drawer: "Start Fund Raising"
///
/// Note: This is intentionally simple and safe:
/// - Media upload not required (Phase B / later)
/// - Payment not integrated (Phase B)
class FundraisingCreateScreen extends ConsumerStatefulWidget {
  const FundraisingCreateScreen({super.key});

  @override
  ConsumerState<FundraisingCreateScreen> createState() =>
      _FundraisingCreateScreenState();
}

class _FundraisingCreateScreenState
    extends ConsumerState<FundraisingCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _picker = ImagePicker();
  final _postsDs = PostsRemoteDs();

  // Donation post media (Phase B implemented)
  final List<File> _images = [];
  File? _video;
  final List<File> _files = []; // PDF/TXT etc.

  final _titleCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  String _category = 'Treatment';

  // BD location dropdown selections (optional; we still submit locationText)
  int? _divisionId;
  int? _districtId;
  int? _upazilaId;
  int? _unionId;
  String? _divisionName;
  String? _districtName;
  String? _upazilaName;
  String? _unionName;
  String? _areaName;

  DateTime? _deadline;
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    _amountCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _syncLocationText() {
    final parts = <String>[];
    if ((_areaName ?? '').trim().isNotEmpty) parts.add(_areaName!.trim());
    if ((_unionName ?? '').trim().isNotEmpty) parts.add(_unionName!.trim());
    if ((_upazilaName ?? '').trim().isNotEmpty) parts.add(_upazilaName!.trim());
    if ((_districtName ?? '').trim().isNotEmpty)
      parts.add(_districtName!.trim());
    if ((_divisionName ?? '').trim().isNotEmpty)
      parts.add(_divisionName!.trim());

    final text = parts.join(', ');
    _locationCtrl.text = text;
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initial = _deadline ?? now.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDate: initial,
    );
    if (picked == null) return;
    setState(
      () => _deadline = DateTime(picked.year, picked.month, picked.day, 23, 59),
    );
  }

  Future<List<File>> _cropImagesOneByOne(List<XFile> picked) async {
    final out = <File>[];
    for (final x in picked) {
      final cropped = await ImageCropper().cropImage(
        sourcePath: x.path,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: const [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2, // Use 3x2 or 4x3 instead of 4x5
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(title: 'Crop Photo'),
        ],
      );
      out.add(File(cropped?.path ?? x.path));
    }
    return out;
  }

  Future<void> _pickImages() async {
    final list = await _picker.pickMultiImage(imageQuality: 100);
    if (list.isEmpty) return;
    final cropped = await _cropImagesOneByOne(list);
    if (cropped.isEmpty) return;
    setState(() {
      _video = null;
      _files.clear();
      _images
        ..clear()
        ..addAll(cropped);
    });
  }

  Future<void> _pickVideo() async {
    final x = await _picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    setState(() {
      _images.clear();
      _files.clear();
      _video = File(x.path);
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt'],
    );
    final paths = result?.paths.whereType<String>().toList() ?? const [];
    if (paths.isEmpty) return;
    setState(() {
      _images.clear();
      _video = null;
      _files
        ..clear()
        ..addAll(paths.map((p) => File(p)));
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    // Avoid "Null check operator used on a null value" if the Form isn't mounted yet.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_deadline == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a deadline')));
      return;
    }

    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target amount must be greater than 0')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(fundraisingRepositoryProvider);

      // Upload campaign media first (images/video/pdf/txt)
      final mediaIds = <int>[];
      for (final f in _images) {
        mediaIds.add(await _postsDs.uploadMedia(f));
      }
      if (_video != null) {
        mediaIds.add(await _postsDs.uploadMedia(_video!));
      }
      for (final f in _files) {
        mediaIds.add(await _postsDs.uploadMedia(f));
      }

      await repo.createCampaign(
        title: _titleCtrl.text.trim(),
        caption: _captionCtrl.text.trim(),
        category: _category,
        locationText: _locationCtrl.text.trim(),
        targetAmount: amount,
        deadline: _deadline!,
        mediaIds: mediaIds,
      );

      // Refresh feed so the new campaign shows immediately
      ref.invalidate(fundraisingFeedProvider);

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fundraiser created successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      // Backend returns 403 if verification form/documents are not completed
      if (msg.contains('(403)')) {
        await showDialog(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Verification info required'),
              content: const Text(
                'Fundraising campaign তৈরি করতে হলে আপনার Verification form পূরণ করে documents upload করা লাগবে।\n'
                '(Verification pending থাকলেও campaign create করা যাবে।)\n\n'
                'Go to Verification screen, profile fill করুন, document upload করুন, তারপর submit দিন।',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // close dialog
                    Navigator.of(context).push(
                      // push screen
                      MaterialPageRoute(
                        builder: (_) => const FundraisingAccountSetupScreen(),
                      ),
                    );
                  },
                  child: const Text('Open Verification'),
                ),
              ],
            );
          },
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $msg')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deadlineText = _deadline == null
        ? 'Select deadline'
        : '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Start Fund Raising')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Title is required';
                    if (t.length < 6)
                      return 'Please write a more descriptive title';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _captionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 4,
                  maxLines: 8,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Description is required';
                    if (t.length < 20)
                      return 'Please add more details (min 20 characters)';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Target Amount (BDT)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    final n = int.tryParse(t);
                    if (n == null) return 'Enter a valid number';
                    if (n <= 0) return 'Must be greater than 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Treatment',
                      child: Text('Treatment'),
                    ),
                    DropdownMenuItem(value: 'Food', child: Text('Food')),
                    DropdownMenuItem(value: 'Shelter', child: Text('Shelter')),
                    DropdownMenuItem(
                      value: 'Vaccination',
                      child: Text('Vaccination'),
                    ),
                    DropdownMenuItem(value: 'Rescue', child: Text('Rescue')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 12),
                // Centralized BD location selector (Division -> District -> Upazila -> Union)
                LocationSelectorWidget(
                  divisionId: _divisionId,
                  districtId: _districtId,
                  upazilaId: _upazilaId,
                  unionId: _unionId,
                  divisionName: _divisionName,
                  districtName: _districtName,
                  upazilaName: _upazilaName,
                  unionName: _unionName,
                  disabled: _submitting,
                  required: true,
                  onDivisionChanged: (id, name) {
                    setState(() {
                      _divisionId = id;
                      _divisionName = name;
                      _districtId = null;
                      _districtName = null;
                      _upazilaId = null;
                      _upazilaName = null;
                      _unionId = null;
                      _unionName = null;
                      _areaName = null;
                      _syncLocationText();
                    });
                  },
                  onDistrictChanged: (id, name) {
                    setState(() {
                      _districtId = id;
                      _districtName = name;
                      _upazilaId = null;
                      _upazilaName = null;
                      _unionId = null;
                      _unionName = null;
                      _areaName = null;
                      _syncLocationText();
                    });
                  },
                  onUpazilaChanged: (id, name) {
                    setState(() {
                      _upazilaId = id;
                      _upazilaName = name;
                      _unionId = null;
                      _unionName = null;
                      _areaName = null;
                      _syncLocationText();
                    });
                  },
                  onUnionChanged: (id, name) {
                    setState(() {
                      _unionId = id;
                      _unionName = name;
                      _areaName = name;
                      _syncLocationText();
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _locationCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Location (auto)',
                    border: OutlineInputBorder(),
                    helperText: 'Select Division → District → Upazila → Union',
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Location is required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Media attachments (Donation post)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ActionChip(
                      icon: Icons.photo,
                      label: 'Add Photos',
                      onTap: _submitting ? null : _pickImages,
                    ),
                    _ActionChip(
                      icon: Icons.videocam,
                      label: 'Add Video',
                      onTap: _submitting ? null : _pickVideo,
                    ),
                    _ActionChip(
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'Add PDF/TXT',
                      onTap: _submitting ? null : _pickFiles,
                    ),
                  ],
                ),

                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 240,
                      width: double.infinity,
                      child: PageView.builder(
                        itemCount: _images.length,
                        itemBuilder: (_, i) {
                          final f = _images[i];
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(f, fit: BoxFit.cover),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black.withOpacity(
                                      0.35,
                                    ),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _submitting
                                      ? null
                                      : () =>
                                            setState(() => _images.removeAt(i)),
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ),
                              if (_images.length > 1)
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.35),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${i + 1}/${_images.length}',
                                      style: context.appText.labelMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],

                if (_files.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ..._files
                      .take(6)
                      .map(
                        (f) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.08),
                            ),
                            color: Colors.grey.withOpacity(0.06),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.attach_file,
                                size: 18,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  f.path.split('/').last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.appText.bodyMedium!,
                                ),
                              ),
                              IconButton(
                                onPressed: _submitting
                                    ? null
                                    : () => setState(() => _files.remove(f)),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],

                if (_video != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_circle_fill,
                          size: 34,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _video!.path.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: _submitting
                              ? null
                              : () => setState(() => _video = null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDeadline,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(deadlineText),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Fundraiser'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Note: Payment gateway is not enabled yet (Phase B).\nDonations are recorded as SUCCESS for now.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: onTap == null ? Colors.black26 : Colors.black54,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? Colors.black26 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
