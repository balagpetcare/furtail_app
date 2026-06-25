import '../entities/story_entity.dart';
import '../../data/repositories/story_repository.dart';

class CreateStoryUseCase {
  final StoryRepository _repo;
  CreateStoryUseCase(this._repo);

  Future<StoryEntity> call({
    required String mediaPath,
    String? caption,
  }) =>
      _repo.createStory(mediaPath: mediaPath, caption: caption);
}