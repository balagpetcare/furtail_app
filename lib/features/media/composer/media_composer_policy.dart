import 'package:furtail_app/features/media/composer/media_draft_item.dart';

class MediaComposerPolicy {
  const MediaComposerPolicy({
    required this.contextKey,
    required this.uploadContext,
    required this.folder,
    this.maxPhotos,
    this.maxVideos,
    this.maxDocuments,
    this.allowedDocumentExtensions = const <String>{'pdf'},
  });

  final String contextKey;
  final String uploadContext;
  final String folder;
  final int? maxPhotos;
  final int? maxVideos;
  final int? maxDocuments;
  final Set<String> allowedDocumentExtensions;

  static const adoption = MediaComposerPolicy(
    contextKey: 'adoption',
    uploadContext: 'adoption',
    folder: 'media',
  );

  static const fundraising = MediaComposerPolicy(
    contextKey: 'fundraising',
    uploadContext: 'fundraising',
    folder: 'fundraising',
    maxPhotos: 8,
    maxVideos: 2,
    maxDocuments: 6,
    allowedDocumentExtensions: <String>{'pdf', 'jpg', 'jpeg', 'png', 'webp'},
  );

  String? validateAddition(
    MediaDraftType type, {
    required int currentPhotos,
    required int currentVideos,
    required int currentDocuments,
    String? fileName,
  }) {
    switch (type) {
      case MediaDraftType.image:
        if (maxPhotos != null && currentPhotos >= maxPhotos!) {
          return 'You can add up to $maxPhotos photos here.';
        }
        return null;
      case MediaDraftType.video:
        if (maxVideos != null && currentVideos >= maxVideos!) {
          return 'You can add up to $maxVideos videos here.';
        }
        return null;
      case MediaDraftType.document:
        if (maxDocuments != null && currentDocuments >= maxDocuments!) {
          return 'You can add up to $maxDocuments documents here.';
        }
        final ext = _extensionOf(fileName);
        if (fileName != null &&
            ext.isNotEmpty &&
            !allowedDocumentExtensions.contains(ext)) {
          return 'Supported document types: ${allowedDocumentExtensions.map((e) => e.toUpperCase()).join(', ')}.';
        }
        return null;
    }
  }

  static String _extensionOf(String? fileName) {
    if (fileName == null || !fileName.contains('.')) return '';
    return fileName.split('.').last.trim().toLowerCase();
  }
}
