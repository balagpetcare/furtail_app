import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/location/presentation/widgets/location_selector_widget.dart';
import '../../data/models/fundraising_models.dart';
import '../providers/fundraising_providers.dart';

/// Unified editor:
/// - Post tab: caption + media
/// - Fundraising tab: title + category + location + target + deadline + status
class FundraisingEditScreen extends ConsumerStatefulWidget {
  final FundraisingCampaign campaign;
  const FundraisingEditScreen({super.key, required this.campaign});

  @override
  ConsumerState<FundraisingEditScreen> createState() => _FundraisingEditScreenState();
}

class _FundraisingEditScreenState extends ConsumerState<FundraisingEditScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

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

  String _category = 'Treatment';
  DateTime? _deadline;
  String _status = 'ACTIVE';

  final _picker = ImagePicker();
  final _postsDs = PostsRemoteDs();
  final List<File> _images = [];
  File? _video;
  final List<File> _files = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);

    final c = widget.campaign;
    _titleCtrl.text = c.title;
    _captionCtrl.text = c.caption?.toString() ?? '';
    _amountCtrl.text = c.targetAmount.toString();
    _locationCtrl.text = c.locationText?.toString() ?? '';
    // NOTE: We don't have location IDs from API yet in this screen.
    // Users can re-select from dropdowns to rebuild locationText.
    _category = (c.category?.toString().trim().isNotEmpty ?? false) ? c.category!.toString() : 'Treatment';
    _deadline = c.deadline;
    _status = c.status;
  }

  void _syncLocationText() {
    final parts = <String>[];
    if ((_areaName ?? '').trim().isNotEmpty) parts.add(_areaName!.trim());
    if ((_unionName ?? '').trim().isNotEmpty) parts.add(_unionName!.trim());
    if ((_upazilaName ?? '').trim().isNotEmpty) parts.add(_upazilaName!.trim());
    if ((_districtName ?? '').trim().isNotEmpty) parts.add(_districtName!.trim());
    if ((_divisionName ?? '').trim().isNotEmpty) parts.add(_divisionName!.trim());
    _locationCtrl.text = parts.join(', ');
  }

  @override
  void dispose() {
    _tab.dispose();
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    _amountCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
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
    setState(() => _deadline = DateTime(picked.year, picked.month, picked.day, 23, 59));
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

  Future<void> _deleteCampaign() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete fundraiser?'),
        content: const Text('This will delete the post and fundraiser.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = ref.read(fundraisingRepositoryProvider);
      await repo.deleteCampaign(campaignId: widget.campaign.id);
      ref.invalidate(fundraisingFeedProvider);
      if (!mounted) return;
      Navigator.pop(context, true);
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final target = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Target amount must be > 0')));
      return;
    }
    if (_deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a deadline')));
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(fundraisingRepositoryProvider);

      // Upload media if user selected new attachments (otherwise keep old media)
      List<int>? newMediaIds;
      if (_images.isNotEmpty || _video != null || _files.isNotEmpty) {
        final ids = <int>[];
        for (final f in _images) {
          ids.add(await _postsDs.uploadMedia(f));
        }
        if (_video != null) {
          ids.add(await _postsDs.uploadMedia(_video!));
        }
        for (final f in _files) {
          ids.add(await _postsDs.uploadMedia(f));
        }
        newMediaIds = ids;
      }

      await repo.updateCampaign(
        campaignId: widget.campaign.id,
        title: _titleCtrl.text.trim(),
        caption: _captionCtrl.text.trim(),
        category: _category,
        locationText: _locationCtrl.text.trim(),
        targetAmount: target,
        deadline: _deadline,
        status: _status,
        mediaIds: newMediaIds,
      );

      ref.invalidate(fundraisingCampaignProvider(widget.campaign.id));
      ref.invalidate(fundraisingFeedProvider);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Fundraiser'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Post'),
            Tab(text: 'Fundraising'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: _saving ? null : _deleteCampaign,
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tab,
          children: [
            // ---------------- Post tab ----------------
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _captionCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Post caption',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.photo),
                      label: const Text('Photo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Video'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('PDF/TXT'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_images.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _images
                        .map((f) => ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(f, width: 90, height: 90, fit: BoxFit.cover),
                            ))
                        .toList(),
                  ),
                if (_video != null) ...[
                  const SizedBox(height: 6),
                  Text('Video selected: ${_video!.path.split('/').last}'),
                ],
                if (_files.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ..._files.map((f) => Text('File: ${f.path.split('/').last}')),
                ],
                if (_images.isEmpty && _video == null && _files.isEmpty && c.media.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Existing media', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: c.media
                        .map((m) => ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(m.url, width: 90, height: 90, fit: BoxFit.cover),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),

            // -------------- Fundraising tab --------------
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Title required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target amount', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Treatment', child: Text('Treatment')),
                    DropdownMenuItem(value: 'Food', child: Text('Food')),
                    DropdownMenuItem(value: 'Shelter', child: Text('Shelter')),
                    DropdownMenuItem(value: 'Rescue', child: Text('Rescue')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? 'Treatment'),
                ),
                const SizedBox(height: 12),
                LocationSelectorWidget(
                  divisionId: _divisionId,
                  districtId: _districtId,
                  upazilaId: _upazilaId,
                  unionId: _unionId,
                  divisionName: _divisionName,
                  districtName: _districtName,
                  upazilaName: _upazilaName,
                  unionName: _unionName,
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Location (auto from dropdowns)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDeadline,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(_deadline == null
                      ? 'Select deadline'
                      : 'Deadline: ${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                    DropdownMenuItem(value: 'PAUSED', child: Text('PAUSED')),
                    DropdownMenuItem(value: 'ENDED', child: Text('ENDED')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'ACTIVE'),
                ),
                const SizedBox(height: 12),
                Text('Tip: Save to update both Post + Fundraising details.', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

