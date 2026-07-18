import 'dart:async' show EventSink, StreamTransformer, unawaited;
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import '../../../../core/auth/secure_storage_service.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/multipart_helper.dart';

import '../models/post_comment_model.dart';
import '../models/post_model.dart';
import '../services/feed_cache_service.dart';

class PagedPostsResult {
  final List<PostModel> items;
  final bool hasMore;
  final int page;
  final int limit;

  const PagedPostsResult({
    required this.items,
    required this.hasMore,
    required this.page,
    required this.limit,
  });
}

class UploadedMediaResult {
  final int id;
  final String? url;
  final String? hlsUrl;
  final String? thumbnailUrl;
  final String? type;

  const UploadedMediaResult({
    required this.id,
    this.url,
    this.hlsUrl,
    this.thumbnailUrl,
    this.type,
  });

  String? get previewUrl {
    final hls = hlsUrl?.trim();
    if (hls != null && hls.isNotEmpty) return hls;
    final direct = url?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    return null;
  }
}

class PostsRemoteDs {
  final SecureStorageService _secureStorage;

  PostsRemoteDs([SecureStorageService? secureStorage])
    : _secureStorage = secureStorage ?? SecureStorageService();

  Future<String?> _token() => _secureStorage.accessToken;

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

    // Persist raw response for offline-first display; no auth data is included.
    unawaited(FeedCacheService().saveRawJson(res.body));

    final decoded = jsonDecode(res.body);
    final list = (decoded['data'] as List?) ?? const [];
    return list
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PagedPostsResult> getVideosFeed({
    int limit = 50,
    int page = 1,
    String? search,
    String? category,
    String? sort,
    String? duration,
    bool? followingOnly,
  }) async {
    final res = await http.get(
      Uri.parse(
        ApiEndpoints.postsVideos(
          limit: limit,
          page: page,
          search: search,
          category: category,
          sort: sort,
          duration: duration,
          followingOnly: followingOnly,
        ),
      ),
      headers: await _authHeaders(json: false),
    );

    if (res.statusCode != 200) {
      throw Exception('Videos feed failed (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final list = (decoded['data'] as List?) ?? const [];
    final items = list
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = decoded['meta'];
    final metaHasMore = meta is Map ? meta['hasMore'] as bool? : null;
    final hasMore = metaHasMore ?? items.length >= limit;
    return PagedPostsResult(
      items: items,
      hasMore: hasMore,
      page: page,
      limit: limit,
    );
  }

  Future<List<PostModel>> getUserFeed({
    required int userId,
    int limit = 50,
  }) async {
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

  Future<PostModel> fetchPostById(int postId) async {
    final res = await http.get(
      Uri.parse(ApiEndpoints.postById(postId: postId)),
      headers: await _authHeaders(json: false),
    );

    if (res.statusCode != 200) {
      throw Exception('Post fetch failed (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    return PostModel.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  /// Upload any media (IMAGE/VIDEO/FILE) using the same backend endpoint.
  /// Supports File + XFile/content:// via multipartFromAnyFile helper.
  Future<int> uploadMedia(
    Object file, {
    int? listingId,
    String? draftId,
    int? trimStartMs,
    int? trimEndMs,
    double? volume,
    bool? mute,
    int? coverTimestampMs,
    String? aspectRatio,
    String? quality,
  }) async {
    final result = await uploadMediaDetailed(
      file,
      listingId: listingId,
      draftId: draftId,
      trimStartMs: trimStartMs,
      trimEndMs: trimEndMs,
      volume: volume,
      mute: mute,
      coverTimestampMs: coverTimestampMs,
      aspectRatio: aspectRatio,
      quality: quality,
    );
    return result.id;
  }

  Future<UploadedMediaResult> uploadMediaDetailed(
    Object file, {
    int? listingId,
    String? draftId,
    int? trimStartMs,
    int? trimEndMs,
    double? volume,
    bool? mute,
    int? coverTimestampMs,
    String? aspectRatio,
    String? quality,
    String? uploadContext,
  }) async {
    final t = await _token();
    if (t == null || t.isEmpty) {
      throw Exception('No token found. Please login again.');
    }

    final uri = Uri.parse('${ApiConfig.apiV1}/media/upload');
    final req = http.MultipartRequest('POST', uri);

    req.headers['Authorization'] = 'Bearer $t';
    req.files.add(await multipartFromAnyFile(file, fieldName: 'file'));

    if (listingId != null) req.fields['listingId'] = listingId.toString();
    if (draftId != null && draftId.isNotEmpty) req.fields['draftId'] = draftId;
    if (uploadContext != null && uploadContext.isNotEmpty)
      req.fields['uploadContext'] = uploadContext;
    if (trimStartMs != null) req.fields['trimStartMs'] = trimStartMs.toString();
    if (trimEndMs != null) req.fields['trimEndMs'] = trimEndMs.toString();
    if (volume != null) req.fields['volume'] = volume.toString();
    if (mute != null) req.fields['mute'] = mute ? '1' : '0';
    if (coverTimestampMs != null)
      req.fields['coverTimestampMs'] = coverTimestampMs.toString();
    if (aspectRatio != null) req.fields['aspectRatio'] = aspectRatio;
    if (quality != null) req.fields['quality'] = quality;

    debugPrint(
      '[PostsRemoteDs.uploadMedia] '
      'endpoint=$uri '
      'hasToken=true '
      'fileField=file '
      'extraFields=${req.fields.keys.toList()}',
    );

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      debugPrint(
        '[PostsRemoteDs.uploadMedia] FAILED '
        'statusCode=${streamed.statusCode} '
        'body=${body.length > 800 ? body.substring(0, 800) : body}',
      );
      throw Exception('Upload failed (${streamed.statusCode}): $body');
    }

    return _decodeUploadedMedia(body);
  }

  /// Upload media with progress callback.
  /// If the input is not a File (e.g., XFile), we fallback to uploadMedia()
  /// because byte-stream progress is only supported easily with File.openRead().
  Future<int> uploadMediaWithProgress(
    Object file, {
    void Function(int sentBytes, int totalBytes)? onProgress,
    int? listingId,
    String? draftId,
    int? trimStartMs,
    int? trimEndMs,
    double? volume,
    bool? mute,
    int? coverTimestampMs,
    String? aspectRatio,
    String? quality,
    String? uploadContext,
  }) async {
    final result = await uploadMediaDetailedWithProgress(
      file,
      onProgress: onProgress,
      listingId: listingId,
      draftId: draftId,
      trimStartMs: trimStartMs,
      trimEndMs: trimEndMs,
      volume: volume,
      mute: mute,
      coverTimestampMs: coverTimestampMs,
      aspectRatio: aspectRatio,
      quality: quality,
      uploadContext: uploadContext,
    );
    return result.id;
  }

  Future<UploadedMediaResult> uploadMediaDetailedWithProgress(
    Object file, {
    void Function(int sentBytes, int totalBytes)? onProgress,
    int? listingId,
    String? draftId,
    int? trimStartMs,
    int? trimEndMs,
    double? volume,
    bool? mute,
    int? coverTimestampMs,
    String? aspectRatio,
    String? quality,
    String? uploadContext,
  }) async {
    // Progress streaming only when it's a real File
    if (file is! File) {
      // No reliable stream progress for XFile/content:// here; upload normally.
      return uploadMediaDetailed(
        file,
        listingId: listingId,
        draftId: draftId,
        trimStartMs: trimStartMs,
        trimEndMs: trimEndMs,
        volume: volume,
        mute: mute,
        coverTimestampMs: coverTimestampMs,
        aspectRatio: aspectRatio,
        quality: quality,
        uploadContext: uploadContext,
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

    final filename = p.basename(file.path);
    req.files.add(
      http.MultipartFile(
        'file',
        fileStream,
        totalBytes,
        filename: filename,
        contentType:
            getMimeTypeFromPath(filename) ??
            MediaType('application', 'octet-stream'),
      ),
    );

    if (listingId != null) req.fields['listingId'] = listingId.toString();
    if (draftId != null && draftId.isNotEmpty) req.fields['draftId'] = draftId;
    if (uploadContext != null && uploadContext.isNotEmpty)
      req.fields['uploadContext'] = uploadContext;
    if (trimStartMs != null) req.fields['trimStartMs'] = trimStartMs.toString();
    if (trimEndMs != null) req.fields['trimEndMs'] = trimEndMs.toString();
    if (volume != null) req.fields['volume'] = volume.toString();
    if (mute != null) req.fields['mute'] = mute ? '1' : '0';
    if (coverTimestampMs != null)
      req.fields['coverTimestampMs'] = coverTimestampMs.toString();
    if (aspectRatio != null) req.fields['aspectRatio'] = aspectRatio;
    if (quality != null) req.fields['quality'] = quality;

    debugPrint(
      '[PostsRemoteDs.uploadMediaWithProgress] '
      'endpoint=$uri '
      'filename=$filename '
      'sizeBytes=$totalBytes '
      'sizeMB=${(totalBytes / 1048576).toStringAsFixed(2)} '
      'hasToken=true '
      'fileField=file '
      'extraFields=${req.fields.keys.toList()}',
    );

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      debugPrint(
        '[PostsRemoteDs.uploadMediaWithProgress] FAILED '
        'filename=$filename '
        'statusCode=${streamed.statusCode} '
        'body=${body.length > 800 ? body.substring(0, 800) : body}',
      );
      throw Exception('Upload failed (${streamed.statusCode}): $body');
    }

    return _decodeUploadedMedia(body);
  }

  UploadedMediaResult _decodeUploadedMedia(String body) {
    final decoded = jsonDecode(body);
    final data = decoded['data'];
    final mediaId = data?['id'];
    if (mediaId == null) {
      throw Exception('mediaId missing: $body');
    }
    return UploadedMediaResult(
      id: (mediaId as num).toInt(),
      url: data?['url']?.toString(),
      hlsUrl: data?['hlsUrl']?.toString(),
      thumbnailUrl: data?['thumbnailUrl']?.toString(),
      type: data?['type']?.toString(),
    );
  }

  Future<PostModel> createPost({
    required String type,
    String? caption,
    List<int> mediaIds = const [],
    String? privacy,
    String? backgroundStyle,
    String? postType,
    String? lostPetName,
    String? lostPetLocation,
    bool lostPetContactVisible = false,
    List<int> taggedPetIds = const [],
    String? locationText,
    String? feelingId,
    String? feelingLabel,
    String? feelingEmoji,
    String? activityId,
    String? activityLabel,
    String? activityEmoji,
    String? songTitle,
    String? songArtist,
    int? songStartMs,
    int? songDurationMs,
  }) async {
    final res = await http.post(
      Uri.parse(ApiEndpoints.postsCreate()),
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'type': type,
        'caption': caption,
        'mediaIds': mediaIds,
        if (privacy != null) 'privacy': privacy,
        if (backgroundStyle != null) 'backgroundStyle': backgroundStyle,
        if (postType != null) 'postType': postType,
        if (locationText != null) 'locationText': locationText,
        if (feelingId != null) 'feelingId': feelingId,
        if (feelingLabel != null) 'feelingLabel': feelingLabel,
        if (feelingEmoji != null) 'feelingEmoji': feelingEmoji,
        if (activityId != null) 'activityId': activityId,
        if (activityLabel != null) 'activityLabel': activityLabel,
        if (activityEmoji != null) 'activityEmoji': activityEmoji,
        // Send lost pet details only when postType is LOST_PET
        if (postType == 'LOST_PET') ...{
          'lostPetDetails': {
            if (lostPetName != null && lostPetName.isNotEmpty)
              'petName': lostPetName,
            if (lostPetLocation != null && lostPetLocation.isNotEmpty)
              'lastSeenLocation': lostPetLocation,
            'contactVisible': lostPetContactVisible,
          },
        },
        if (taggedPetIds.isNotEmpty) 'taggedPetIds': taggedPetIds,
        if (songTitle != null) 'songTitle': songTitle,
        if (songArtist != null) 'songArtist': songArtist,
        if (songStartMs != null) 'songStartMs': songStartMs,
        if (songDurationMs != null) 'songDurationMs': songDurationMs,
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
    String? backgroundStyle,
    String? postType,
    String? lostPetName,
    String? lostPetLocation,
    bool? lostPetContactVisible,
    List<int>? taggedPetIds,
    String? locationText,
    String? feelingId,
    String? feelingLabel,
    String? feelingEmoji,
    String? activityId,
    String? activityLabel,
    String? activityEmoji,
    String? songTitle,
    String? songArtist,
    int? songStartMs,
    int? songDurationMs,
  }) async {
    final payload = <String, dynamic>{
      if (caption != null) 'caption': caption,
      if (type != null) 'type': type,
      if (mediaIds != null) 'mediaIds': mediaIds,
      if (backgroundStyle != null) 'backgroundStyle': backgroundStyle,
      if (postType != null) 'postType': postType,
      if (locationText != null) 'locationText': locationText,
      if (feelingId != null) 'feelingId': feelingId,
      if (feelingLabel != null) 'feelingLabel': feelingLabel,
      if (feelingEmoji != null) 'feelingEmoji': feelingEmoji,
      if (activityId != null) 'activityId': activityId,
      if (activityLabel != null) 'activityLabel': activityLabel,
      if (activityEmoji != null) 'activityEmoji': activityEmoji,
      if (postType == 'LOST_PET')
        'lostPetDetails': {
          if (lostPetName != null && lostPetName.isNotEmpty)
            'petName': lostPetName,
          if (lostPetLocation != null && lostPetLocation.isNotEmpty)
            'lastSeenLocation': lostPetLocation,
          'contactVisible': lostPetContactVisible ?? false,
        },
      if (taggedPetIds != null) 'taggedPetIds': taggedPetIds,
      if (songTitle != null) 'songTitle': songTitle,
      if (songArtist != null) 'songArtist': songArtist,
      if (songStartMs != null) 'songStartMs': songStartMs,
      if (songDurationMs != null) 'songDurationMs': songDurationMs,
    };

    debugPrint(
      '[PostsRemoteDs] updatePost REQUEST: '
      'method=PATCH '
      'url=${ApiEndpoints.postsUpdate(postId: postId)} '
      'mediaIds=$mediaIds '
      'caption="${caption ?? ''}" '
      'backgroundStyle=$backgroundStyle '
      'feelingId=$feelingId '
      'activityId=$activityId '
      'locationText=$locationText',
    );

    final res = await http.patch(
      Uri.parse(ApiEndpoints.postsUpdate(postId: postId)),
      headers: await _authHeaders(json: true),
      body: jsonEncode(payload),
    );

    debugPrint(
      '[PostsRemoteDs] updatePost RESPONSE: '
      'statusCode=${res.statusCode} '
      'body=${res.body.length > 500 ? '${res.body.substring(0, 500)}...' : res.body}',
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

  // â”€â”€ Phase 1: Cursor-based comment pagination â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  /// Fetch comments with cursor-based pagination.
  /// Returns a tuple-like map with `items` (List<PostCommentModel>) and `nextCursor` (String?).
  Future<Map<String, dynamic>> listCommentsCursor(
    int postId, {
    int limit = 30,
    String? cursor,
  }) async {
    String url = '${ApiEndpoints.postsComments(postId: postId, limit: limit)}';
    if (cursor != null && cursor.isNotEmpty) {
      url += '&cursor=${Uri.encodeQueryComponent(cursor)}';
    }
    final res = await http.get(
      Uri.parse(url),
      headers: await _authHeaders(json: false),
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Comments cursor failed (${res.statusCode}): ${res.body}',
      );
    }
    final decoded = jsonDecode(res.body);
    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    final items = (data['items'] as List?) ?? (data as List?) ?? const [];
    return <String, dynamic>{
      'items': items
          .map((e) => PostCommentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      'nextCursor': data['nextCursor']?.toString(),
    };
  }

  // â”€â”€ Phase 1: Edit comment â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  /// Edit an existing comment's text.
  Future<PostCommentModel> editComment({
    required int postId,
    required int commentId,
    required String text,
  }) async {
    final res = await http.patch(
      Uri.parse(
        ApiEndpoints.postsCommentEdit(postId: postId, commentId: commentId),
      ),
      headers: await _authHeaders(json: true),
      body: jsonEncode({'text': text}),
    );
    if (res.statusCode != 200) {
      throw Exception('Edit comment failed (${res.statusCode}): ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    return PostCommentModel.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  // â”€â”€ Phase 1: Delete comment â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  /// Delete a comment by id.
  Future<void> deleteComment({
    required int postId,
    required int commentId,
  }) async {
    final res = await http.delete(
      Uri.parse(
        ApiEndpoints.postsCommentDelete(postId: postId, commentId: commentId),
      ),
      headers: await _authHeaders(json: false),
    );
    if (res.statusCode != 200) {
      throw Exception('Delete comment failed (${res.statusCode}): ${res.body}');
    }
  }

  // â”€â”€ Phase 1: Share post â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  /// Record a share of a post. Returns response data (e.g., updated shareCount).
  Future<Map<String, dynamic>> sharePost(int postId) async {
    final res = await http.post(
      Uri.parse(ApiEndpoints.postsShare(postId: postId)),
      headers: await _authHeaders(json: false),
    );
    if (res.statusCode != 200) {
      throw Exception('Share post failed (${res.statusCode}): ${res.body}');
    }
    return (jsonDecode(res.body)['data'] as Map?)?.cast<String, dynamic>() ??
        {};
  }

  // â”€â”€ Phase 1: Record post view â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  /// Record a view of a post. Returns response data (e.g., updated viewCount).
  Future<Map<String, dynamic>> recordView(int postId) async {
    final res = await http.post(
      Uri.parse(ApiEndpoints.postsView(postId: postId)),
      headers: await _authHeaders(json: false),
    );
    if (res.statusCode != 200) {
      throw Exception('Record view failed (${res.statusCode}): ${res.body}');
    }
    return (jsonDecode(res.body)['data'] as Map?)?.cast<String, dynamic>() ??
        {};
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

  Future<Map<String, dynamic>> getUserPhotoGallery({
    required int userId,
    int limit = 50,
    String? cursor,
  }) async {
    final uri = Uri.parse(
      ApiEndpoints.postsUserPhotos(userId: userId, limit: limit) +
          (cursor != null ? "&cursor=$cursor" : ""),
    );
    final res = await http.get(uri, headers: await _authHeaders(json: false));

    if (res.statusCode != 200) {
      throw Exception(
        'User photo gallery failed (${res.statusCode}): ${res.body}',
      );
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return (decoded['data'] as Map<String, dynamic>?) ?? const {};
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
    final data = (decoded['data'] as Map<String, dynamic>?) ?? const {};
    return PostModel.fromJson(data);
  }

  Future<void> bookmarkPost({required int postId}) async {
    final res = await http.post(
      Uri.parse(ApiEndpoints.bookmarkPost(postId: postId)),
      headers: await _authHeaders(json: false),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Bookmark failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<void> unbookmarkPost({required int postId}) async {
    final res = await http.delete(
      Uri.parse(ApiEndpoints.unbookmarkPost(postId: postId)),
      headers: await _authHeaders(json: false),
    );

    if (res.statusCode != 200) {
      throw Exception('Unbookmark failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<List<PostModel>> getBookmarkedPosts({
    int limit = 50,
    String? cursor,
  }) async {
    final uri = Uri.parse(
      ApiEndpoints.bookmarkedPosts(limit: limit) +
          (cursor != null ? "&cursor=$cursor" : ""),
    );
    final res = await http.get(uri, headers: await _authHeaders(json: false));

    if (res.statusCode != 200) {
      throw Exception(
        'Get bookmarked posts failed (${res.statusCode}): ${res.body}',
      );
    }

    final decoded = jsonDecode(res.body);
    final list = (decoded['data']?['items'] as List?) ?? const [];
    return list
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
