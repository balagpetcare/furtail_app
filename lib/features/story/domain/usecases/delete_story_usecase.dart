import '../../data/repositories/story_repository.dart';

class DeleteStoryUseCase {
  final StoryRepository _repo;
  DeleteStoryUseCase(this._repo);

  Future<void> call(int storyId) => _repo.deleteStory(storyId);
}