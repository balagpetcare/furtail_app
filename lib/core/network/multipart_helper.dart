import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

MediaType? getMimeTypeFromPath(String filepath) {
  final ext = filepath.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    case 'png':
      return MediaType('image', 'png');
    case 'gif':
      return MediaType('image', 'gif');
    case 'webp':
      return MediaType('image', 'webp');
    case 'mp4':
      return MediaType('video', 'mp4');
    case 'mov':
      return MediaType('video', 'quicktime');
    case 'm4v':
      return MediaType('video', 'x-m4v');
    case 'avi':
      return MediaType('video', 'x-msvideo');
    case 'mkv':
      return MediaType('video', 'x-matroska');
    case 'webm':
      return MediaType('video', 'webm');
    default:
      return null;
  }
}

/// Creates a [http.MultipartFile] from either a [File] or an [XFile].
///
/// Why:
/// - On many real Android devices, pickers return `content://` backed files.
/// - `MultipartFile.fromPath()` can fail with `content://` paths.
/// This helper falls back to reading bytes for [XFile].
Future<http.MultipartFile> multipartFromAnyFile(
  Object file, {
  String fieldName = 'file',
}) async {
  if (file is File) {
    return http.MultipartFile.fromPath(
      fieldName,
      file.path,
      filename: p.basename(file.path),
      contentType: getMimeTypeFromPath(file.path),
    );
  }

  if (file is XFile) {
    final bytes = await file.readAsBytes();
    return http.MultipartFile.fromBytes(
      fieldName,
      bytes,
      filename: file.name,
      contentType: getMimeTypeFromPath(file.name),
    );
  }

  throw Exception('Unsupported file type: ${file.runtimeType}');
}
