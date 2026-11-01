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
      // Everyone followed who has an active story — all of them: their
      // stories and profiles are on the phone, and the grid only builds the
      // cards on screen. (It used to take 15, more on reaching the end — and
      // stopped there for good once one of those 15 expired.) Unwatched
      // first, newest first; then the watched, newest first.
      await emit.forEach<List<(User, List<Story>)>>(
        _storiesRepository.followingStoriesFeed(),
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
