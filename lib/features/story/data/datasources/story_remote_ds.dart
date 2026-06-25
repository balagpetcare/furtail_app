import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/story_model.dart';

/// Remote data source for story CRUD.
/// Uses the existing [ApiClient] for all HTTP calls.
class StoryRemoteDs {
  final ApiClient _client;

  StoryRemoteDs(this._client);

  /// GET /api/v1/stories/feed
  /// Sends auth token when the user is logged in so the server can mark
  /// isOwnStory=true for the current user's stories.
  Future<List<StoryModel>> getStories({int limit = 50}) async {
    final prefs = await SharedPreferences.getInstance();
    final hasToken = (prefs.getString('token') ?? '').isNotEmpty;
    final data = await _client.get(
      ApiEndpoints.storiesFeed(limit: limit),
      auth: hasToken, // send token when logged in for isOwnStory resolution
    );
    final list = (data['stories'] ?? data['data'] ?? []) as List;
    return list
        .map((e) => StoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/v1/stories
  Future<StoryModel> createStory({
    required String mediaPath,
    String? caption,
  }) async {
    final data = await _client.multipartPost(
      url: ApiEndpoints.storiesCreate(),
      fieldName: 'media',
      filePath: mediaPath,
      fields: caption != null && caption.trim().isNotEmpty
          ? {'caption': caption.trim()}
          : null,
    );
    final story = data['story'] ?? data['data'] ?? data;
    return StoryModel.fromJson(story as Map<String, dynamic>);
  }

  /// POST /api/v1/stories/:id/view — best-effort, errors ignored by caller.
  Future<void> markViewed(int storyId) async {
    await _client.post(
      ApiEndpoints.storiesView(storyId),
      {},
      auth: true, // must be authenticated to track per-user views
    );
  }

  /// DELETE /api/v1/stories/:id
  Future<void> deleteStory(int storyId) async {
    await _client.delete(ApiEndpoints.storiesDelete(storyId));
  }
}
