import '../entities/story_entity.dart';
import '../../data/repositories/story_repository.dart';

class GetStoriesUseCase {
  final StoryRepository _repo;
  GetStoriesUseCase(this._repo);

  Future<List<StoryEntity>> call({int limit = 50}) =>
      _repo.getStories(limit: limit);
}