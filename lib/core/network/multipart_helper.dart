import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

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
    );
  }

  if (file is XFile) {
    final bytes = await file.readAsBytes();
    return http.MultipartFile.fromBytes(
      fieldName,
      bytes,
      filename: file.name,
    );
  }

  throw Exception('Unsupported file type: ${file.runtimeType}');
}
