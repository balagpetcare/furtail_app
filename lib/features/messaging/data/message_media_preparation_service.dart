import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kDebugMode, debugPrint;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:furtail_app/features/media/data/authenticated_media_uploader.dart';

/// Client-side adaptive compression for chat image attachments (COMMAND —
/// "minimum working messaging media"). Mirrors the backend's default
/// messaging-media policy (`DEFAULT_MESSAGING_MEDIA_SETTINGS` in
/// media-settings.service.ts) so a selected photo is already a small,
/// upload-ready chat image *before* it ever reaches the network — sending a
/// message must not depend on the server-side image worker (which may not
/// be running) to produce anything usable.
///
/// Video and audio are intentionally pass-through here (source-size
/// validation only): per this feature's minimum-viable scope, transcoding
/// happens server-side, optionally, after the message has already sent with
/// the original file.
class MessageMediaPreparationService {
  const MessageMediaPreparationService();

  static const int maxWidth = 1280;
  static const int maxHeight = 1280;
  static const int targetPreferredBytes = 40 * 1024;
  static const int hardMaxBytes = 55 * 1024;
  static const int minQuality = 30;
  static const int maxQuality = 82;

  /// Reads, downsizes (preserving aspect ratio, never upscaling/cropping),
  /// and adaptively JPEG-compresses [source] toward [targetPreferredBytes]
  /// (never worse than [hardMaxBytes] except when the quality floor is
  /// already hit — successful sending beats byte-perfect compression). If
  /// the file can't be decoded as an image at all (unsupported/corrupt), the
  /// original file is returned unchanged rather than failing the send.
  Future<File> prepareImage(File source) async {
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty) {
      throw const MediaUploadException(
        kind: MediaUploadErrorKind.invalidPayload,
        userMessage:
            'The selected image is empty. Please choose a different file.',
      );
    }

    final Uint8List? compressed = await compute(_compressImageBytes, bytes);
    if (compressed == null) {
      // Not decodable by this library (e.g. an exotic format) — the
      // original file is still a perfectly valid upload; the backend
      // independently re-validates/re-sniffs it regardless.
      if (kDebugMode) {
        debugPrint('[MessageMedia] image decode failed, using original file');
      }
      return source;
    }

    if (kDebugMode) {
      debugPrint(
        '[MessageMedia] compressed image ${bytes.length}B -> ${compressed.length}B',
      );
    }

    final dir = await getTemporaryDirectory();
    final targetDir = Directory(p.join(dir.path, 'furtail-message-media'));
    await targetDir.create(recursive: true);
    final target = File(
      p.join(
        targetDir.path,
        'msg_img_${DateTime.now().microsecondsSinceEpoch}.jpg',
      ),
    );
    await target.writeAsBytes(compressed, flush: true);
    return target;
  }

  /// Video/audio: no client-side transcoding in this minimum implementation
  /// — the original file is uploaded as-is (size/type already validated by
  /// the caller before this is invoked). Kept as explicit pass-through
  /// methods (rather than callers just skipping preparation) so every
  /// attachment type flows through one preparation service, per this
  /// feature's spec.
  Future<File> prepareVideo(File source) async => source;

  Future<File> prepareAudio(File source) async => source;
}

/// Runs on a background isolate via [compute] — decoding + resizing +
/// repeated JPEG re-encoding of a full-resolution camera photo is heavy
/// enough to jank the UI thread if run inline.
Uint8List? _compressImageBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  var working = decoded;
  const maxWidth = MessageMediaPreparationService.maxWidth;
  const maxHeight = MessageMediaPreparationService.maxHeight;
  if (working.width > maxWidth || working.height > maxHeight) {
    final widthRatio = maxWidth / working.width;
    final heightRatio = maxHeight / working.height;
    final scale = widthRatio < heightRatio ? widthRatio : heightRatio;
    final targetWidth = (working.width * scale).round().clamp(1, maxWidth);
    working = img.copyResize(
      working,
      width: targetWidth,
      interpolation: img.Interpolation.average,
    );
  }

  const hardMaxBytes = MessageMediaPreparationService.hardMaxBytes;
  const minQuality = MessageMediaPreparationService.minQuality;
  const maxQuality = MessageMediaPreparationService.maxQuality;

  // Iterative quality reduction: resize once, then encode/inspect/reduce —
  // never a single fixed `quality = 50` shot.
  Uint8List encoded = img.encodeJpg(working, quality: maxQuality);
  var quality = maxQuality;
  while (encoded.length > hardMaxBytes && quality > minQuality) {
    quality = (quality - 12).clamp(minQuality, maxQuality);
    encoded = img.encodeJpg(working, quality: quality);
  }

  // Still over the hard cap at the quality floor (a genuinely complex
  // image): shrink dimensions further rather than degrading quality below
  // the usability floor. A handful of bounded passes — this must never
  // fail the send outright, so whatever the last pass produces is what
  // gets sent (Part 4: successful usable sending beats byte-perfect
  // compression).
  var shrinkAttempts = 0;
  while (encoded.length > hardMaxBytes &&
      shrinkAttempts < 4 &&
      working.width > 320 &&
      working.height > 320) {
    working = img.copyResize(
      working,
      width: (working.width * 0.8).round(),
      interpolation: img.Interpolation.average,
    );
    encoded = img.encodeJpg(working, quality: minQuality);
    shrinkAttempts++;
  }

  return encoded;
}
