import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/multipart_helper.dart';

import '../models/post_comment_model.dart';
import '../models/post_model.dart';

class PostsRemoteDs {
  Future<String?> _token() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('token');
  }

  Future<Map<String, String>> _authHeaders({bool json = true}) async {
    final t = await _token();
    return <String, String>{
      if (t != null) 'Authorization': 'Bearer $t',
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<List<PostModel>> getFeed({int limit = 50}) async {
    final res = await http.get(
      Uri.parse(ApiEndpoints.postsFeed(limit: limit)),
      headers: await _authHeaders(json: false),
    );

    if (res.statusCode != 200) {
      throw Exception('Feed failed (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final list = (decoded['data'] as List?) ?? const [];
    return list
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PostModel>> getUserFeed({required int userId, int limit = 50}) async {
    final res = await http.get(
      Uri.parse(ApiEndpoints.postsUserFeed(userId: userId, limit: limit)),
      headers: await _authHeaders(json: false),
    );

    if (res.statusCode != 200) {
      throw Exception('User feed failed (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final list = (decoded['data'] as List?) ?? const [];
    return list
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Upload any media (IMAGE/VIDEO/FILE) using the same backend endpoint.
  /// Supports File + XFile/content:// via multipartFromAnyFile helper.
  Future<int> uploadMedia(
    Object file, {
    int? trimStartMs,
    int? trimEndMs,
    double? volume,
    bool? mute,
  }) async {
    final t = await _token();
    if (t == null || t.isEmpty) {
      throw Exception('No token found. Please login again.');
    }

    final uri = Uri.parse('${ApiConfig.apiV1}/media/upload');
    final req = http.MultipartRequest('POST', uri);

    req.headers['Authorization'] = 'Bearer $t';
    req.files.add(await multipartFromAnyFile(file, fieldName: 'file'));

    if (trimStartMs != null) req.fields['trimStartMs'] = trimStartMs.toString();
    if (trimEndMs != null) req.fields['trimEndMs'] = trimEndMs.toString();
    if (volume != null) req.fields['volume'] = volume.toString();
    if (mute != null) req.fields['mute'] = mute ? '1' : '0';

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      throw Exception('Upload failed (${streamed.statusCode}): $body');
    }

    final decoded = jsonDecode(body);
    final mediaId = decoded['data']?['id'];
    if (mediaId == null) throw Exception('mediaId missing: $body');
    return (mediaId as num).toInt();
  }

  /// Upload media with progress callback.
  /// If the input is not a File (e.g., XFile), we fallback to uploadMedia()
  /// because byte-stream progress is only supported easily with File.openRead().
  Future<int> uploadMediaWithProgress(
    Object file, {
    void Function(int sentBytes, int totalBytes)? onProgress,
    int? trimStartMs,
    int? trimEndMs,
    double? volume,
    bool? mute,
  }) async {
    // Progress streaming only when it's a real File
    if (file is! File) {
      // No reliable stream progress for XFile/content:// here; upload normally.
      return uploadMedia(
        file,
        trimStartMs: trimStartMs,
        trimEndMs: trimEndMs,
        volume: volume,
        mute: mute,
      );
    }

    final t = await _token();
    if (t == null || t.isEmpty) {
      throw Exception('No token found. Please login again.');
    }

    final int totalBytes = await file.length();
    int sentBytes = 0;

    final Stream<List<int>> fileStream = file.openRead().transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (List<int> data, EventSink<List<int>> sink) {
          sentBytes += data.length;
          onProgress?.call(sentBytes, totalBytes);
          sink.add(data);
        },
      ),
    );

    final uri = Uri.parse('${ApiConfig.apiV1}/media/upload');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $t';

    req.files.add(
      http.MultipartFile(
        'file',
        fileStream,
        totalBytes,
        filename: p.basename(file.path),
      ),
    );

    if (trimStartMs != null) req.fields['trimStartMs'] = trimStartMs.toString();
    if (trimEndMs != null) req.fields['trimEndMs'] = trimEndMs.toString();
    if (volume != null) req.fields['volume'] = volume.toString();
    if (mute != null) req.fields['mute'] = mute ? '1' : '0';

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      throw Exception('Upload failed (${streamed.statusCode}): $body');
    }

    final decoded = jsonDecode(body);
    final mediaId = decoded['data']?['id'];
    if (mediaId == null) throw Exception('mediaId missing: $body');
    return (mediaId as num).toInt();
  }

  Future<PostModel> createPost({
    required String type,
    String? caption,
    List<int> mediaIds = const [],
  }) async {
    final res = await http.post(
      Uri.parse(ApiEndpoints.postsCreate()),
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'type': type,
        'caption': caption,
        'mediaIds': mediaIds,
      }),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Create post failed (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    return PostModel.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  Future<PostModel> updatePost({
    required int postId,
    String? caption,
    String? type,
    List<int>? mediaIds,
  }) async {
    final payload = <String, dynamic>{
      if (caption != null) 'caption': caption,
      if (type != null) 'type': type,
      if (mediaIds != null) 'mediaIds': mediaIds,
    };

    final res = await http.patch(
      Uri.parse(ApiEndpoints.postsUpdate(postId: postId)),
      headers: await _authHeaders(json: true),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('Update post failed (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    return PostModel.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  Future<void> deletePost({required int postId}) async {
    final res = await http.delete(
      Uri.parse(ApiEndpoints.postsDelete(postId: postId)),
      headers: await _authHeaders(json: false),
    );

    if (res.statusCode != 200) {
      throw Exception('Delete post failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<Map<String, dynamic>> likePost(int postId) async {
    final res = await http.post(
      Uri.parse(ApiEndpoints.postsLike(postId: postId)),
      headers: await _authHeaders(json: false),
    );
    if (res.statusCode != 200) {
      throw Exception('Like failed (${res.statusCode}): ${res.body}');
    }
    return (jsonDecode(res.body)['data'] as Map?)?.cast<String, dynamic>() ??
        {};
  }

  Future<Map<String, dynamic>> unlikePost(int postId) async {
    final res = await http.delete(
      Uri.parse(ApiEndpoints.postsUnlike(postId: postId)),
      headers: await _authHeaders(json: false),
    );
    if (res.statusCode != 200) {
      throw Exception('Unlike failed (${res.statusCode}): ${res.body}');
    }
    return (jsonDecode(res.body)['data'] as Map?)?.cast<String, dynamic>() ??
        {};
  }

  Future<List<PostCommentModel>> listComments(
    int postId, {
    int limit = 100,
  }) async {
    final res = await http.get(
      Uri.parse(ApiEndpoints.postsComments(postId: postId, limit: limit)),
      headers: await _authHeaders(json: false),
    );
    if (res.statusCode != 200) {
      throw Exception('Comments failed (${res.statusCode}): ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    final list = (decoded['data'] as List?) ?? const [];
    return list
        .map((e) => PostCommentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PostCommentModel> addComment(int postId, String text) async {
    final res = await http.post(
      Uri.parse(ApiEndpoints.postsAddComment(postId: postId)),
      headers: await _authHeaders(json: true),
      body: jsonEncode({'text': text}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Add comment failed (${res.statusCode}): ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    return PostCommentModel.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> likeComment({
    required int postId,
    required int commentId,
  }) async {
    final res = await http.post(
      Uri.parse(
        ApiEndpoints.postsCommentLike(postId: postId, commentId: commentId),
      ),
      headers: await _authHeaders(json: false),
    );
    if (res.statusCode != 200) {
      throw Exception('Comment like failed (${res.statusCode}): ${res.body}');
    }
    return (jsonDecode(res.body)['data'] as Map?)?.cast<String, dynamic>() ??
        {};
  }

  Future<Map<String, dynamic>> unlikeComment({
    required int postId,
    required int commentId,
  }) async {
    final res = await http.delete(
      Uri.parse(
        ApiEndpoints.postsCommentUnlike(postId: postId, commentId: commentId),
      ),
      headers: await _authHeaders(json: false),
    );
    if (res.statusCode != 200) {
      throw Exception('Comment unlike failed (${res.statusCode}): ${res.body}');
    }
    return (jsonDecode(res.body)['data'] as Map?)?.cast<String, dynamic>() ??
        {};
  }

  Future<PostCommentModel> addReply({
    required int postId,
    required int commentId,
    required String text,
  }) async {
    final res = await http.post(
      Uri.parse(
        ApiEndpoints.postsCommentReply(postId: postId, commentId: commentId),
      ),
      headers: await _authHeaders(json: true),
      body: jsonEncode({'text': text}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Reply failed (${res.statusCode}): ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    return PostCommentModel.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  /// Backwards-compatible alias used by older UI code.
  Future<PostCommentModel> replyComment({
    required int postId,
    required int commentId,
    required String text,
  }) {
    return addReply(postId: postId, commentId: commentId, text: text);
  }

  Future<Map<String, dynamic>> getUserPhotoGallery({required int userId, int limit = 50, String? cursor}) async {
    final uri = Uri.parse(ApiEndpoints.postsUserPhotos(userId: userId, limit: limit) + (cursor != null ? "&cursor=$cursor" : ""));
    final res = await http.get(uri, headers: await _authHeaders(json: false));

    if (res.statusCode != 200) {
      throw Exception('User photo gallery failed (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return (decoded['data'] as Map<String, dynamic>? ) ?? const {};
  }

  Future<PostModel> getPostById({required int postId}) async {
    final res = await http.get(
      Uri.parse(ApiEndpoints.postById(postId: postId)),
      headers: await _authHeaders(json: false),
    );

    if (res.statusCode != 200) {
      throw Exception('Get post failed (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (decoded['data'] as Map<String, dynamic>? ) ?? const {};
    return PostModel.fromJson(data);
  }

}
