import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/stories/bloc/story_ordering.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:user_repository/user_repository.dart';

part 'stories_event.dart';
part 'stories_state.dart';

class StoriesBloc extends Bloc<StoriesEvent, StoriesState> {
  StoriesBloc({
    required StoriesRepository storiesRepository,
  }) : _storiesRepository = storiesRepository,
       super(const StoriesState.initial()) {
    on<StoriesFetchUserFollowingsStories>(
      _onStoriesFetchUserFollowingsStories,
      // The handler keeps a subscription open for good, so a pull-to-refresh
      // has to replace it — concurrently would leave two feeds fighting.
      transformer: restartable(),
    );
    on<StoriesStorySeen>(_onStoriesStorySeen);
    on<StoriesStoryDeleteRequested>(_onStoriesStoryDeleteRequested);
  }

  final StoriesRepository _storiesRepository;

  /// How many story-havers the tray currently subscribes to. Grows by
  /// [_storyPageSize] each time the carousel scrolls to its end.
  static const _storyPageSize = 15;
  int _storyLimit = _storyPageSize;

  /// The current story-haver window size — the carousel only asks to grow while
  /// the window is full (`state.users.length >= storyLimit`), so it stops once
  /// every haver is loaded.
  int get storyLimit => _storyLimit;

  /// Subscribes to the stories of everyone the user follows and keeps the list
  /// ordered for as long as this bloc lives.
  ///
  /// Held open rather than read once: the previous version took `.first` of
  /// each feed, so a story posted after the tab opened stayed invisible until a
  /// pull-to-refresh. Now PowerSync pushes new and expired stories straight in,
  /// and marking one seen re-sorts the grid on the spot.
  Future<void> _onStoriesFetchUserFollowingsStories(
    StoriesFetchUserFollowingsStories event,
    Emitter<StoriesState> emit,
  ) async {
    try {
      // Bounded to followings who actually have an active story (resolved by a
      // single reactive query), so the tray no longer opens a live feed and
      // fetches a profile for EVERY followed user. Still live: a new/expired
      // story re-emits the author set. The window grows on scroll (restartable
      // re-subscribes with the wider limit).
      if (event.grow) _storyLimit += _storyPageSize;
      await emit.forEach<List<(User, List<Story>)>>(
        _storiesRepository.followingStoriesFeed(limit: _storyLimit),
        onData: (pairs) {
          final withStories = [...pairs]
            ..sort((a, b) => compareStoryAuthors(a.$2, b.$2));
          return state.copyWith(
            users: withStories.map((entry) => entry.$1).toList(),
            status: StoriesStatus.success,
          );
        },
        onError: (error, stackTrace) {
          addError(error, stackTrace);
          return state.copyWith(status: StoriesStatus.failure);
        },
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: StoriesStatus.failure));
    }
  }

  Future<void> _onStoriesStorySeen(
    StoriesStorySeen event,
    Emitter<StoriesState> emit,
  ) async {
    try {
      await _storiesRepository.setUserStorySeen(
        story: event.story,
        userId: event.userId,
      );
      emit(state.copyWith(status: StoriesStatus.success));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: StoriesStatus.failure));
    }
  }

  Future<void> _onStoriesStoryDeleteRequested(
    StoriesStoryDeleteRequested event,
    Emitter<StoriesState> emit,
  ) async {
    try {
      await _storiesRepository.deleteStory(id: event.id);
      event.onStoryDeleted?.call();
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: StoriesStatus.failure));
    }
  }
}
