import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'story_editor_screen.dart';
import 'story_text_composer_screen.dart';

/// Entry point for story creation.
/// Shows two choices:
///   1. "Select File" — picks image or video, then navigates to StoryEditorScreen
///   2. "Create Text Story" — navigates to StoryTextComposerScreen
///
/// No upload happens here. Upload is the responsibility of the editor screens.
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  bool _isPicking = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        foregroundColor: cs.onSurface,
        title: Text(
          'Add to My Day',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // ── Illustration ──────────────────────────────────────────────
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 48,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Share your moment',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    'Stories disappear after 24 hours.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // ── Select File button ────────────────────────────────────────
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _isPicking ? null : _selectFile,
                  icon: _isPicking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.perm_media_outlined),
                  label: Text(
                    _isPicking ? 'Opening…' : 'Select File',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Text story button ─────────────────────────────────────────
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _openTextComposer,
                  icon: const Icon(Icons.text_fields_rounded),
                  label: const Text(
                    'Create Text Story',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // ── Hint ──────────────────────────────────────────────────────
              Center(
                child: Text(
                  'Supports photos and videos',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectFile() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      // Show picker type bottom sheet
      final source = await _showPickerSheet();
      if (source == null || !mounted) return;

      XFile? picked;
      bool isVideo = false;

      if (source == 'image') {
        picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
      } else if (source == 'video') {
        picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
        isVideo = true;
      } else if (source == 'camera') {
        picked = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
        );
      }

      if (picked == null || !mounted) return;

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => StoryEditorScreen(
            filePath: picked!.path,
            isVideo: isVideo,
          ),
        ),
      );

      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open media: ${e.toString().replaceAll("Exception: ", "")}',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<String?> _showPickerSheet() {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose Photo from Gallery'),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Choose Video from Gallery'),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx, null),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openTextComposer() {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StoryTextComposerScreen()),
    ).then((created) {
      if (created == true && mounted) Navigator.pop(context, true);
    });
  }
}
