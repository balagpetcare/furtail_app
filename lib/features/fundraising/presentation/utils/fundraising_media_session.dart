import 'dart:io';

import 'package:image_picker/image_picker.dart';

import '../../../media/composer/media_draft_item.dart';

class FundraisingMediaSession {
  FundraisingMediaSession._({
    required this.sessionId,
    required this.contentType,
    required this.contentId,
  });

  final String sessionId;
  final String contentType;
  final String contentId;

  factory FundraisingMediaSession.forCreate({required String draftSessionId}) {
    final cleanSessionId = _sanitizeSessionId(draftSessionId);
    return FundraisingMediaSession._(
      sessionId: 'fundraising:create:$cleanSessionId',
      contentType: 'FUNDRAISING_DRAFT',
      contentId: cleanSessionId,
    );
  }

  factory FundraisingMediaSession.forCampaign({required int campaignId}) {
    final cleanSessionId = campaignId.toString();
    return FundraisingMediaSession._(
      sessionId: 'fundraising:campaign:$cleanSessionId',
      contentType: 'FUNDRAISING_CAMPAIGN',
      contentId: cleanSessionId,
    );
  }

  factory FundraisingMediaSession.forUpdate({
    required int campaignId,
    required String composerSessionId,
  }) {
    final cleanSessionId = _sanitizeSessionId(composerSessionId);
    return FundraisingMediaSession._(
      sessionId: 'fundraising:update:$campaignId:$cleanSessionId',
      contentType: 'FUNDRAISING_UPDATE',
      contentId: '$campaignId:$cleanSessionId',
    );
  }

  String idempotencyKeyFor(String itemId) => '$sessionId:$itemId';

  static String _sanitizeSessionId(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[^A-Za-z0-9._:-]+'), '-');
    return cleaned.isEmpty ? 'session' : cleaned;
  }
}

Object fundraisingMultipartSourceFor(MediaDraftItem item) {
  final localPath = item.localPath?.trim();
  if (localPath == null || localPath.isEmpty) {
    throw StateError('Missing local media path for ${item.id}');
  }

  final file = File(localPath);
  if (file.existsSync()) {
    return file;
  }

  return XFile(localPath, name: item.fileName);
}
