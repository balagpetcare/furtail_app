import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/secure_storage_service.dart';
import '../../../../services/api_client.dart';
import '../../data/datasources/story_remote_ds.dart';
import '../../data/repositories/story_repository.dart';
import '../../domain/entities/story_entity.dart';
import '../../domain/usecases/create_story_usecase.dart';
import '../../domain/usecases/delete_story_usecase.dart';
import '../../domain/usecases/get_stories_usecase.dart';

// Public repository provider — used by StoryViewerScreen for markViewed
final storyRepositoryProvider = Provider<StoryRepository>(
  (ref) => StoryRepository(ref.watch(_storyRemoteDsProvider)),
);

// ── Internal providers ───────────────────────────────────────────────────────

final _storyRemoteDsProvider = Provider<StoryRemoteDs>(
  (ref) => StoryRemoteDs(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageServiceProvider),
  ),
);

final _storyRepositoryProvider = Provider<StoryRepository>(
  (ref) => ref.watch(storyRepositoryProvider),
);

final getStoriesUseCaseProvider = Provider<GetStoriesUseCase>(
  (ref) => GetStoriesUseCase(ref.watch(_storyRepositoryProvider)),
);

final createStoryUseCaseProvider = Provider<CreateStoryUseCase>(
  (ref) => CreateStoryUseCase(ref.watch(_storyRepositoryProvider)),
);

final deleteStoryUseCaseProvider = Provider<DeleteStoryUseCase>(
  (ref) => DeleteStoryUseCase(ref.watch(_storyRepositoryProvider)),
);

// ── Stateful story feed notifier ────────────────────────────────────────────

class StoryFeedNotifier extends StateNotifier<AsyncValue<List<StoryEntity>>> {
  final GetStoriesUseCase _getStories;
  final CreateStoryUseCase _createStory;
  final DeleteStoryUseCase _deleteStory;
  final StoryRepository _repository;

  bool _disposed = false;

  StoryFeedNotifier(
    this._getStories,
    this._createStory,
    this._deleteStory,
    this._repository,
  ) : super(const AsyncValue.loading()) {
    refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Refresh the story feed.
  /// - If there is already data, keeps it visible during the refresh (no blank flash).
  /// - On transient error, preserves whatever was shown before.
  Future<void> refresh({int limit = 50}) async {
    final prev = state.valueOrNull;
    if (prev == null) {
      state = const AsyncValue.loading();
    }
    try {
      final stories = await _getStories(limit: limit);
      if (!_disposed) state = AsyncValue.data(stories);
    } catch (e, st) {
      if (!_disposed) {
        if (prev != null) {
          // Transient error — keep the existing data visible
          state = AsyncValue.data(prev);
        } else {
          state = AsyncValue.error(e, st);
        }
      }
    }
  }

  /// Upload a story. Throws on upload failure so the UI can show the error.
  /// On success, inserts the new story optimistically and refreshes in background.
  Future<StoryEntity> createStory({
    required String mediaPath,
    String? caption,
  }) async {
    // Upload — let exceptions propagate to the caller
    final story = await _createStory(mediaPath: mediaPath, caption: caption);

    // Optimistic update: show the new story immediately without waiting for refresh
    if (!_disposed) {
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([story, ...current]);
    }

    // Background refresh to get authoritative server data (incl. isOwnStory)
    _silentRefresh();

    return story;
  }

  Future<void> deleteStory(int storyId) async {
    try {
      await _deleteStory(storyId);
      await refresh();
    } catch (e, st) {
      if (!_disposed) state = AsyncValue.error(e, st);
    }
  }

  /// Best-effort view tracking — never shows an error to the user.
  Future<void> markViewed(int storyId) async {
    try {
      await _repository.markViewed(storyId);
    } catch (_) {}
  }

  void _silentRefresh() {
    refresh().catchError((_) {
      /* keep optimistic state */
    });
  }
}

final storyFeedProvider =
    StateNotifierProvider<StoryFeedNotifier, AsyncValue<List<StoryEntity>>>(
      (ref) => StoryFeedNotifier(
        ref.watch(getStoriesUseCaseProvider),
        ref.watch(createStoryUseCaseProvider),
        ref.watch(deleteStoryUseCaseProvider),
        ref.watch(storyRepositoryProvider),
      ),
    );
