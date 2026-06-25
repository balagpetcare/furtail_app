import '../../domain/entities/story_entity.dart';
import '../datasources/story_remote_ds.dart';
import '../models/story_model.dart';

class StoryRepository {
  final StoryRemoteDs _remoteDs;

  StoryRepository(this._remoteDs);

  Future<List<StoryEntity>> getStories({int limit = 50}) async {
    final models = await _remoteDs.getStories(limit: limit);
    return models.map(_toEntity).toList();
  }

  Future<StoryEntity> createStory({
    required String mediaPath,
    String? caption,
  }) async {
    final model = await _remoteDs.createStory(
      mediaPath: mediaPath,
      caption: caption,
    );
    return _toEntity(model);
  }

  Future<void> markViewed(int storyId) => _remoteDs.markViewed(storyId);

  Future<void> deleteStory(int storyId) => _remoteDs.deleteStory(storyId);

  StoryEntity _toEntity(StoryModel m) => StoryEntity(
    id: m.id,
    userId: m.userId,
    userName: m.userName,
    userAvatarUrl: m.userAvatarUrl,
    mediaUrl: m.mediaUrl,
    mediaType: m.mediaType,
    caption: m.caption,
    createdAt: m.createdAt,
    isViewedByMe: m.isViewedByMe,
    isOwnStory: m.isOwnStory,
    viewCount: m.viewCount,
  );
}